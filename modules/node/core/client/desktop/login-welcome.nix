{
  config,
  pkgs,
  lib,
  nodeHostName ? "node-client",
  ...
}:

let
  # ASCII art NODE
  nodeAsciiArt = ''
    ╔═══════════════════════════════════════╗
    ║                                       ║
    ║        ██████╗  █████╗  ██████╗      ║
    ║        ██╔══██╗██╔══██╗██╔════╝      ║
    ║        ██████╔╝███████║██║  ███╗     ║
    ║        ██╔══██╗██╔══██║██║   ██║     ║
    ║        ██║  ██║██║  ██║╚██████╔╝     ║
    ║        ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝      ║
    ║                                       ║
    ║        Thin Client Enterprise OS      ║
    ║                                       ║
    ╚═══════════════════════════════════════╝
  '';

  # Script que coleta info do sistema
  sysInfoScript = pkgs.writeShellScriptBin "node-sysinfo" ''
    #!/bin/bash
    # Exibir informações do sistema

    # Cores
    BOLD='\033[1m'
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    RESET='\033[0m'

    echo -e "$BLUE${nodeAsciiArt}$RESET"

    echo -e "$BOLD$GREEN=== SISTEMA$RESET"
    echo -e "Host: $BOLD$(hostname)$RESET"
    echo -e "Kernel: $BOLD$(uname -r)$RESET"
    echo -e "Uptime: $BOLD$(uptime -p 2>/dev/null || uptime)$RESET"
    echo ""

    echo -e "$BOLD$GREEN=== HARDWARE$RESET"
    CPU_MODEL=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
    CPU_CORES=$(nproc)
    echo -e "CPU: $BOLD$CPU_MODEL ($CPU_CORES cores)$RESET"

    TOTAL_RAM=$(free -h | awk 'NR==2 {print $2}')
    USED_RAM=$(free -h | awk 'NR==2 {print $3}')
    echo -e "RAM: $BOLD$USED_RAM / $TOTAL_RAM$RESET"

    # Disco
    DISK_INFO=$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')
    echo -e "Disco: $BOLD$DISK_INFO$RESET"
    echo ""

    echo -e "$BOLD$GREEN=== REDE$RESET"
    # IP principal
    IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "não configurado")
    echo -e "IPv4: $BOLD$IP$RESET"

    # Gateway
    GW=$(ip route | grep default | awk '{print $3}' | head -1)
    echo -e "Gateway: $BOLD''${GW:-não configurado}$RESET"

    # DNS
    DNS=$(cat /etc/resolv.conf 2>/dev/null | grep nameserver | head -1 | awk '{print $2}')
    echo -e "DNS: $BOLD''${DNS:-automático}$RESET"
    echo ""

    echo -e "$BOLD$GREEN=== USUARIO$RESET"
    echo -e "Admin: $BOLD$(whoami)$RESET"
    echo -e "Shell: $BOLD$SHELL$RESET"
    echo -e "Home: $BOLD$HOME$RESET"
    echo ""

    echo -e "$CYAN━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$RESET"
    echo -e "$BOLD$GREEN$(date '+%a, %d %b %Y %H:%M:%S')$RESET"
    echo ""
  '';

  # Login welcome script
  loginWelcomeScript = pkgs.writeShellScriptBin "node-login-welcome" ''
    #!/bin/bash
    # Mostrado no login TTY

    # Limpar tela
    clear

    # Exibir info do sistema
    "${sysInfoScript}/bin/node-sysinfo"

    # Se fastfetch disponível, mostrar também
    if command -v fastfetch &>/dev/null; then
      echo -e "\033[0;36m▶ Informações Detalhadas:\033[0m"
      fastfetch --logo none 2>/dev/null | tail -20
    fi
  '';

in
{
  # Instalar packages necessários
  environment.systemPackages = with pkgs; [
    fastfetch
    sysInfoScript
    loginWelcomeScript
  ];

  # Banner de login no TTY (antes do prompt)
  environment.etc."issue".text = lib.mkForce ''
    ╔═══════════════════════════════════════╗
    ║      Bem-vindo ao NODE Thin Client   ║
    ║      Host: ${nodeHostName}
    ║      Pressione Ctrl+D para fechar     ║
    ╚═══════════════════════════════════════╝

  '';

  environment.etc."issue.net".text = lib.mkForce ''
    ╔═══════════════════════════════════════╗
    ║      NODE Thin Client ${nodeHostName}
    ║     Authorized Access Only            ║
    ╚═══════════════════════════════════════╝
  '';

  # Bash profile — executado ao fazer login
  environment.etc."profile.d/node-welcome.sh".text = ''
    # Mostrar welcome info apenas em login interativo (TTY)
    if [[ $- == *i* ]] && [[ -z "''${NODE_WELCOME_SHOWN}" ]]; then
        ${loginWelcomeScript}/bin/node-login-welcome
        export NODE_WELCOME_SHOWN=1
    fi
  '';

  # Zsh profile (se usar zsh)
  environment.etc."zprofile".text = lib.mkDefault ''
    # Zsh login profile
    if [[ -f /etc/profile ]]; then
      source /etc/profile
    fi
  '';
}
