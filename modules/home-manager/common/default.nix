# Home Manager: módulo comum (base do usuário)
# Autor: Gabriel Aguiar Rocha (RAGton) + Codex
# Data: 2026-03-12
#
# O que é
# - Ponto de entrada de configuração do Home Manager para o usuário.
# - Agrega imports de programas/serviços e define variáveis de sessão comuns.
#
# Por quê
# - Mantém os `home/*/default.nix` (por-host) pequenos e focados.
# - Centraliza defaults consistentes entre máquinas.
#
# Como
# - Importa módulos em `modules/home-manager/**`.
# - Define `home.username`, `home.homeDirectory`, `home.sessionVariables`.
#
# Riscos
# - Variáveis de sessão podem afetar apps Electron/Qt; mudanças devem ser testadas em Wayland/X11.
{
  userConfig,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  antigravityPackage =
    inputs.antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.default.override
      {
        extraBwrapArgs = [
          "--bind-try /etc/kryonix/ /etc/kryonix/"
          "--symlink kryonix /etc/ragos"
        ];
      };
in
{
  imports = [
    (
      { lib, ... }:
      {
        imports = [
          (lib.mkAliasOptionModule [ "rag" ] [ "kryonix" ])
        ];
      }
    )
    ../programs/aerospace
    ../programs/tilix
    ../programs/warp-terminal
    ../programs/albert
    ../programs/ai-workstation
    ../programs/atuin
    ../programs/bat
    ../programs/mangohud
    ../programs/zen-browser
    ../programs/btop
    ../programs/fastfetch
    ../programs/fzf
    ../programs/git
    ../programs/go
    ../programs/rust
    ../programs/gpg
    ../programs/k9s
    ../programs/krew
    ../programs/lazygit
    ../programs/neovim
    ../programs/obs-studio
    ../programs/rofi
    ../programs/saml2aws
    ../programs/starship
    ../programs/telegram
    ../programs/vscode
    ../programs/virt-manager
    ../programs/jupyter
    ../programs/zellij
    ../programs/zsh
    ../scripts
    ../services/cliphist
    ../services/flatpak
    ../services/kryonix-brain-tunnel
    ../services/kryonix-wayvnc
    ../services/kryonix-krdp
    ../services/kryonix-glacier-vnc-tunnel
    ../services/kryonix-ollama-tunnel
    ../services/kryonix-bar.nix
  ];

  # Habilita Jupyter via módulo declarativo.
  # IMPORTANTE: manter opt-in por host/usuário, porque Jupyter/kernels podem quebrar builds
  # (ex.: xeus-cling e dependências python binárias). Habilite em `home/<user>/<host>/default.nix`.
  # programs.jupyter.enable = true;

  # Recarrega unidades do systemd de forma suave ao mudar configs.
  systemd.user.startServices = "sd-switch";

  # Mantém a CLI do Home Manager disponível depois que o próprio perfil é ativado.
  programs.home-manager.enable = true;

  # Identidade do usuário (paths variam entre Linux e macOS).
  home = {
    username = "${userConfig.name}";
    homeDirectory =
      if pkgs.stdenv.isDarwin then "/Users/${userConfig.name}" else "/home/${userConfig.name}";
    stateVersion = "26.05"; # Versão base para compatibilidade de estado do usuário
  };

  # Ajustes de sessão (principalmente Electron/VS Code em Wayland).
  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    GTK_USE_PORTAL = "1";

    # Fusion combina melhor com apps Qt Quick quando o stack usa Kvantum em Qt Widgets.
    QT_QUICK_CONTROLS_STYLE = "Fusion";

    # Evita cair no libvirt rootless (qemu:///session), que não consegue criar bridges.
    LIBVIRT_DEFAULT_URI = "qemu:///system";
  };

  # Garante que os pacotes comuns estejam instalados
  home.packages = with pkgs; [
    awscli2
    dig
    dust
    eza
    fd
    jq
    kubectl
    nh
    openconnect
    pipenv
    podman-compose
    podman-tui
    emacs

    # =========================
    # Python (interpretador)
    # =========================
    # O que é
    # - Runtime Python para uso no terminal/IDE.
    # - Tooling básico: pip e virtualenv para ambientes isolados.
    #
    # Como usar
    # - Criar venv: `python -m venv .venv`
    # - Ativar: `source .venv/bin/activate`
    #
    # Nota
    # - Alguns tools/IDEs ainda chamam o comando `python`.
    # - No nixpkgs atual, o pacote `python3` pode expor `python` e `python3`.
    #   Se o seu editor ainda reclamar, use um venv no projeto e aponte para `.venv/bin/python`.
    python3
    python3Packages.pip
    python3Packages.virtualenv

    ripgrep
    antigravityPackage
  ];
}
