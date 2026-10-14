# Minecraft Setup para Regata OS & Linux 🎮⛏️

Instalação e configuração automatizada do **Minecraft: Java Edition** no **Regata OS** (e outras distribuições Linux baseadas em Flatpak/openSUSE/Ubuntu/Debian), com suporte nativo a controles/joysticks e correção definitiva para o problema de login recorrente da conta Microsoft.

---

## 🎯 Problemas que este script resolve

1. **Suporte completo a Controles (Joysticks):**
   - O Minecraft Java no Linux não possui suporte nativo a controles.
   - O script instala o **Fabric Loader** e os mods **Controlify**, **Fabric API**, **YACL** e **ModMenu**, permitindo jogar com controles como **8BitDo**, **Xbox**, **PlayStation** e genéricos, com vibração, mira analógica e interface de console idêntica à Bedrock.
   - Libera permissão de sandbox (`device=all`) para o jogo enxergar os dispositivos USB e Bluetooth em `/dev/input`.

2. **Fim do "pedindo senha toda vez" (Persistência de Login):**
   - No Flatpak, o Minecraft Launcher tenta armazenar o token OAuth da Microsoft no chaveiro seguro do sistema (`gnome-keyring` via D-Bus `org.freedesktop.secrets`).
   - Sem permissão explícita, o sandbox bloqueia a gravação e o jogo esquece a conta assim que é fechado.
   - O script aplica automaticamente as políticas de D-Bus necessárias (`org.freedesktop.secrets`, `org.gnome.keyring`, `org.kde.kwalletd5/6`), garantindo que você só faça login uma única vez.

3. **Automação 100% pós-formatação:**
   - Em vez de baixar o launcher, instalar o Fabric manualmente, garimpar mods compatíveis no Modrinth e configurar o `launcher_profiles.json`, basta rodar um único comando após formatar o computador.

---

## 🚀 Como Executar

### Opção 1: Execução direta com um único comando (Recomendada)
Após formatar ou em um novo sistema, abra o terminal e execute:

```bash
curl -fsSL https://raw.githubusercontent.com/marquimRcc/minecraft-regataos-linux/main/instalarMinecraft.sh | bash
```

### Opção 2: Clonando o repositório
```bash
git clone https://github.com/marquimRcc/minecraft-regataos-linux.git
cd minecraft-regataos-linux
chmod +x instalarMinecraft.sh
./instalarMinecraft.sh
```

> **Dica:** Para especificar uma versão específica do jogo em vez da última release estável, passe a versão como argumento:
> ```bash
> ./instalarMinecraft.sh 26.3
> ```

---

## 📋 Pré-requisitos
O script verifica automaticamente os requisitos, mas para referência:
- **Flatpak** (já presente por padrão no Regata OS);
- **Java 21+** (OpenJDK / Temurin);
- **Python 3** e **curl**.

No Regata OS / openSUSE:
```bash
sudo zypper install java-21-openjdk curl python3
```

---

## 🛠️ O que o script faz por baixo dos panos

1. Habilita o remoto **Flathub** (se necessário) e instala o `com.mojang.Minecraft`.
2. Aplica overrides no Flatpak para acesso a `/dev/input` e aos serviços de chaveiro D-Bus (`org.freedesktop.secrets`, `org.gnome.keyring`).
3. Consulta dinamicamente as versões oficiais mais recentes via APIs da Mojang, Fabric e Modrinth.
4. Executa o **Fabric Installer** silenciosamente no diretório `.minecraft` do usuário.
5. Faz download automático dos arquivos `.jar` compatíveis dos mods:
   - `controlify`
   - `fabric-api`
   - `yacl`
   - `modmenu`
6. Cria e ajusta a instalação no `launcher_profiles.json` com o nome **"Fabric (Controle)"** já pré-selecionada como padrão para o botão **JOGAR**.

---

## 🎮 Ajustes de Controle dentro do Jogo
Quando o jogo abrir com o mod Controlify:
- Uma tela de boas-vindas detectará automaticamente o seu controle conectado.
- Para calibrar zonas mortas, sensibilidade ou remapear botões, basta pausar o jogo e clicar no ícone do controle na tela de pausa ou ir em **Opções** > **Controles** > **Configurações do Controle**.

---

## 📄 Licença
Distribuído sob a licença MIT. Sinta-se à vontade para utilizar, modificar e compartilhar.
