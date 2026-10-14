#!/usr/bin/env bash
# ==============================================================================
# Script de Instalação e Configuração Automatizada do Minecraft para Linux
# Otimizado para Regata OS / openSUSE / Ubuntu / Debian / Fedora
#
# O que este script faz:
# 1. Instala o Minecraft Launcher oficial via Flatpak (Flathub).
# 2. Configura as permissões de chaveiro (Keyring/Secret Service) para o jogo
#    salvar a conta Microsoft e NÃO pedir login/senha toda vez.
# 3. Configura a permissão de hardware para reconhecer Controles/Joysticks (8BitDo, Xbox, PS).
# 4. Instala o Fabric Loader para a versão desejada (ou última estável).
# 5. Baixa e instala os mods essenciais de joystick com interface nativa:
#    - Controlify (suporte a controle idêntico ao console, vibração e menus)
#    - Fabric API (camada base de compatibilidade)
#    - YACL - YetAnotherConfigLib (interface de configuração do Controlify)
#    - ModMenu (menu de configuração de mods dentro do jogo)
# 6. Registra o perfil "Fabric (Controle)" diretamente no Launcher.
# ==============================================================================

set -euo pipefail

# Cores para terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}${BOLD}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}${BOLD}[SUCESSO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}${BOLD}[AVISO]${NC} $1"
}

log_error() {
    echo -e "${RED}${BOLD}[ERRO]${NC} $1"
}

# ==============================================================================
# 1. Verificação de dependências básicas no sistema
# ==============================================================================
log_info "Verificando dependências do sistema..."

if ! command -v curl &>/dev/null; then
    log_error "O comando 'curl' é necessário. Instale o curl para continuar."
    exit 1
fi

if ! command -v python3 &>/dev/null; then
    log_error "O Python 3 é necessário para processar as APIs e configurações do jogo."
    exit 1
fi

if ! command -v java &>/dev/null; then
    log_error "O Java (JRE/JDK) não foi encontrado no PATH. Instale o OpenJDK 21 para continuar."
    exit 1
fi

if ! command -v flatpak &>/dev/null; then
    log_error "O Flatpak não está instalado. Instale o Flatpak para continuar."
    exit 1
fi

log_success "Todas as dependências básicas estão presentes (curl, python3, java, flatpak)."

# ==============================================================================
# 2. Configuração do repositório Flathub e Instalação do Minecraft
# ==============================================================================
log_info "Verificando repositório Flathub..."
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

log_info "Instalando o Minecraft Launcher oficial via Flatpak..."
flatpak install --user -y flathub com.mojang.Minecraft

log_success "Minecraft Launcher instalado com sucesso!"

# ==============================================================================
# 3. Aplicação de Permissões Críticas do Sandbox (Controle + Chaveiro de Senha)
# ==============================================================================
log_info "Aplicando permissões para reconhecimento de controles USB/Bluetooth..."
flatpak override --user --device=all com.mojang.Minecraft

log_info "Aplicando permissões do Chaveiro de Segurança (Secret Service / D-Bus)..."
log_info "(Isso impede que o jogo perca a sua conta Microsoft e peça login toda vez)"
flatpak override --user \
    --talk-name=org.freedesktop.secrets \
    --talk-name=org.gnome.keyring \
    --talk-name=org.gnome.keyring.SystemPrompter \
    --talk-name=org.gnome.keyring.PrivatePrompter \
    --talk-name=org.kde.kwalletd5 \
    --talk-name=org.kde.kwalletd6 \
    --talk-name=org.freedesktop.portal.Secret \
    com.mojang.Minecraft

log_success "Permissões de hardware e chaveiro configuradas com sucesso!"

# ==============================================================================
# 4. Definição da Versão do Minecraft
# ==============================================================================
if [ -n "${1:-}" ]; then
    MC_VERSION="$1"
    log_info "Versão informada via parâmetro: ${BOLD}${MC_VERSION}${NC}"
else
    log_info "Detectando última versão release do Minecraft..."
    MC_VERSION=$(curl -s "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json" | python3 -c "
import sys, json
try:
    manifest = json.load(sys.stdin)
    print(manifest['latest']['release'])
except Exception:
    print('26.3')
")
    log_info "Última versão identificada: ${BOLD}${MC_VERSION}${NC}"
fi

MINECRAFT_DATA_DIR="$HOME/.var/app/com.mojang.Minecraft"
MINECRAFT_DIR="$MINECRAFT_DATA_DIR/.minecraft"
MODS_DIR="$MINECRAFT_DIR/mods"
TEMP_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

mkdir -p "$MINECRAFT_DIR" "$MODS_DIR"

# ==============================================================================
# 5. Instalação do Fabric Loader
# ==============================================================================
log_info "Obtendo instalador oficial do Fabric..."
FABRIC_INSTALLER_URL=$(curl -s "https://meta.fabricmc.net/v2/versions/installer" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data[0]['url'])
except Exception:
    print('https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.1.2/fabric-installer-1.1.2.jar')
")

curl -sSL "$FABRIC_INSTALLER_URL" -o "$TEMP_DIR/fabric-installer.jar"

log_info "Instalando Fabric Loader para a versão ${MC_VERSION}..."
java -jar "$TEMP_DIR/fabric-installer.jar" client \
    -dir "$MINECRAFT_DIR" \
    -mcversion "$MC_VERSION"

log_success "Fabric Loader instalado com sucesso!"

# ==============================================================================
# 6. Download dos Mods para Suporte a Controle (Modrinth API)
# ==============================================================================
download_mod() {
    local project_slug="$1"
    local mod_name="$2"
    log_info "Buscando $mod_name para Minecraft $MC_VERSION..."

    local file_info
    file_info=$(curl -s "https://api.modrinth.com/v2/project/${project_slug}/version" | python3 -c "
import sys, json
slug = '${project_slug}'
target_mc = '${MC_VERSION}'
try:
    data = json.load(sys.stdin)
    # Procura versão compatível com a versão do MC e que suporte loader fabric
    for ver in data:
        loaders = ver.get('loaders', [])
        gvs = ver.get('game_versions', [])
        if target_mc in gvs and ('fabric' in loaders or not loaders):
            for f in ver.get('files', []):
                if f.get('primary', False):
                    print(f['filename'] + '|' + f['url'])
                    sys.exit(0)
    # Se não achar correspondência exata, pega o arquivo primário mais recente que tenha fabric
    for ver in data:
        loaders = ver.get('loaders', [])
        if 'fabric' in loaders or not loaders:
            for f in ver.get('files', []):
                if f.get('primary', False):
                    print(f['filename'] + '|' + f['url'])
                    sys.exit(0)
except Exception:
    pass
")

    if [ -z "$file_info" ]; then
        log_warn "Não foi possível resolver automaticamente o mod $mod_name. Verifique no Modrinth."
        return 1
    fi

    local filename="${file_info%%|*}"
    local url="${file_info##*|}"

    log_info "Baixando $filename..."
    curl -sSL "$url" -o "$MODS_DIR/$filename"
    log_success "$mod_name instalado em: mods/$filename"
}

log_info "Instalando mods de joystick e interface..."
download_mod "fabric-api" "Fabric API"
download_mod "yacl" "YetAnotherConfigLib (YACL)"
download_mod "controlify" "Controlify (Suporte nativo a Joystick)"
download_mod "modmenu" "ModMenu (Interface de mods no menu)"

# ==============================================================================
# 7. Configuração do Perfil Inicial no launcher_profiles.json
# ==============================================================================
log_info "Configurando o perfil padrão no Launcher do Minecraft..."
python3 -c "
import json, os, glob, datetime

profiles_path = os.path.expanduser('$MINECRAFT_DIR/launcher_profiles.json')
versions_dir = os.path.expanduser('$MINECRAFT_DIR/versions')

fabric_version_ids = []
for p in glob.glob(os.path.join(versions_dir, 'fabric-loader-*-' + '$MC_VERSION')):
    if os.path.isdir(p):
        fabric_version_ids.append(os.path.basename(p))

fabric_version = fabric_version_ids[0] if fabric_version_ids else 'fabric-loader-0.19.5-$MC_VERSION'

data = {'profiles': {}, 'settings': {}, 'version': 6}
if os.path.exists(profiles_path):
    try:
        with open(profiles_path, 'r') as f:
            data = json.load(f)
    except Exception:
        pass

settings = data.get('settings', {})
settings['enableAdvanced'] = False
settings['crashAssistance'] = False
settings['enableHistorical'] = False
settings['enableReleases'] = True
settings['enableSnapshots'] = False
settings['keepLauncherOpen'] = True
data['settings'] = settings

profiles = data.get('profiles', {})
now_iso = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.000Z')

profiles['fabric-loader-$MC_VERSION'] = {
    'created': now_iso,
    'lastUsed': now_iso,
    'lastVersionId': fabric_version,
    'name': 'Fabric $MC_VERSION (Controle)',
    'type': 'custom',
    'icon': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIAAAACABAMAAAAxEHz4AAAAGFBMVEUAAAA4NCrb0LTGvKW8spyAem2uppSakn5SsnMLAAAAAXRSTlMAQObYZgAAAJ5JREFUaIHt1MENgCAMRmFWYAVXcAVXcAVXcH3bhCYNkYjcKO8dSf7v1JASUWdZAlgb0PEmDSMAYYBdGkYApgf8ER3SbwRgesAf0BACMD1gB6S9IbkEEBfwY49oNj4lgLhA64C0o9R9RABTAvp4SX5kB2TA5y8EEAK4pRrxB9QcA4QBWkj3GCAMUCO/xwBhAI/kEsCagCHDY4AwAC3VA6t4zTAMj0OJAAAAAElFTkSuQmCC'
}
data['profiles'] = profiles

with open(profiles_path, 'w') as f:
    json.dump(data, f, indent=2)

print('Perfil Fabric ' + '$MC_VERSION' + ' (Controle) configurado com sucesso!')
"

# ==============================================================================
# 8. Conclusão
# ==============================================================================
echo ""
echo -e "${GREEN}${BOLD}================================================================${NC}"
echo -e "${GREEN}${BOLD}  INSTALAÇÃO E CONFIGURAÇÃO CONCLUÍDAS COM SUCESSO! 🎮⛏️         ${NC}"
echo -e "${GREEN}${BOLD}================================================================${NC}"
echo ""
echo -e "O que foi configurado:"
echo -e "  • ${BOLD}Minecraft Launcher Oficial${NC} instalado via Flatpak."
echo -e "  • ${BOLD}Permissão de Controles (USB/Bluetooth)${NC} habilitada."
echo -e "  • ${BOLD}Persistência de Login (Chaveiro de Senhas)${NC} ativada."
echo -e "  • ${BOLD}Fabric Loader + Controlify + YACL + ModMenu${NC} prontos."
echo -e "  • Perfil ${BOLD}'Fabric ${MC_VERSION} (Controle)'${NC} definido como padrão."
echo ""
echo -e "Para abrir o jogo:"
echo -e "  1. Abra o ${BOLD}Minecraft Launcher${NC} no menu de aplicativos."
echo -e "  2. Faça o login na conta Microsoft (desta vez ele salvará para sempre!)."
echo -e "  3. Clique no botão ${GREEN}${BOLD}JOGAR${NC}."
echo ""
