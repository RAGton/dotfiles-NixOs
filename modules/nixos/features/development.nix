# =============================================================================
# Feature: Development Environment
# Autor: rag (via AI Maintainer)
#
# O que é:
# - Ferramentas e ambientes de desenvolvimento
# - Git, editors, language servers, containers
#
# Por quê:
# - Centraliza configuração de desenvolvimento
# - Escolhe linguagens via opções
# - Mantém consistência entre hosts
#
# Como usar:
# No host:
#   kryonix.features.development.enable = true;
#   kryonix.features.development.languages.rust.enable = true;
#
# Riscos:
# - Muitos language servers podem usar bastante RAM
# - Ajuste conforme necessidade do host
# =============================================================================
{
  config,
  lib,
  pkgs,
  userConfig,
  ...
}:

let
  cfg = config.kryonix.features.development;
  winePackage =
    if pkgs ? wineWow64Packages && pkgs.wineWow64Packages ? waylandFull then
      pkgs.wineWow64Packages.waylandFull
    else if pkgs ? wineWowPackages && pkgs.wineWowPackages ? waylandFull then
      pkgs.wineWowPackages.waylandFull
    else if pkgs ? wine-wayland then
      pkgs.wine-wayland
    else
      pkgs.wine;

  psimPrefixRelative = ".local/share/wineprefixes/psim";

  psimPrefixInit = pkgs.writeShellApplication {
    name = "psim-prefix-init";
    runtimeInputs = [
      winePackage
      pkgs.coreutils
      pkgs.findutils
      pkgs.winetricks
    ];
    text = ''
            set -euo pipefail

            export WINEPREFIX="$HOME/${psimPrefixRelative}"
            mkdir -p "$(dirname "$WINEPREFIX")"

            if [ ! -f "$WINEPREFIX/system.reg" ]; then
              echo "Inicializando o prefixo do PSIM em $WINEPREFIX"
              wineboot -u
            fi

            echo "Instalando componentes recomendados do Wine (corefonts, vcrun2019)..."
            winetricks -q corefonts vcrun2019 || true

            cat <<'EOF'
      Prefixo pronto.
      Use:
        psim-install /caminho/para/o-instalador.exe
      EOF
    '';
  };

  psimInstall = pkgs.writeShellApplication {
    name = "psim-install";
    runtimeInputs = [
      psimPrefixInit
      winePackage
      pkgs.coreutils
    ];
    text = ''
      set -euo pipefail

      if [ $# -lt 1 ]; then
        echo "Uso: psim-install /caminho/para/o-instalador.exe" >&2
        exit 1
      fi

      installer="$1"
      if [ ! -e "$installer" ]; then
        echo "Instalador não encontrado: $installer" >&2
        exit 1
      fi

      psim-prefix-init
      export WINEPREFIX="$HOME/${psimPrefixRelative}"

      exec wine start /unix "$installer"
    '';
  };

  psimLauncher = pkgs.writeShellApplication {
    name = "psim";
    runtimeInputs = [
      winePackage
      pkgs.coreutils
      pkgs.findutils
    ];
    text = ''
      set -euo pipefail

      export WINEPREFIX="$HOME/${psimPrefixRelative}"

      if [ ! -f "$WINEPREFIX/system.reg" ]; then
        echo "O prefixo do PSIM ainda não existe." >&2
        echo "Rode: psim-prefix-init" >&2
        exit 1
      fi

      exe=""
      for candidate in \
        "$WINEPREFIX/drive_c/Program Files/PSIM/PSIM.exe" \
        "$WINEPREFIX/drive_c/Program Files (x86)/PSIM/PSIM.exe"; do
        if [ -f "$candidate" ]; then
          exe="$candidate"
          break
        fi
      done

      if [ -z "$exe" ]; then
        exe="$(find "$WINEPREFIX/drive_c" -type f \( -iname 'PSIM.exe' -o -iname 'Psim.exe' -o -iname '*psim*.exe' \) -print -quit 2>/dev/null || true)"
      fi

      if [ -z "$exe" ]; then
        echo "PSIM não encontrado no prefixo atual." >&2
        echo "Rode: psim-install /caminho/para/o-instalador.exe" >&2
        exit 1
      fi

      exec wine "$exe" "$@"
    '';
  };

in
{
  imports = [
    (lib.mkRemovedOptionModule [
      "kryonix"
      "features"
      "development"
      "editors"
      "vscode"
      "enable"
    ] "Use kryonix.vscode instead.")
  ];

  options.kryonix.features.development = {
    enable = lib.mkEnableOption "Ambiente de desenvolvimento";

    git = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Habilita Git e ferramentas relacionadas";
      };
    };

    languages = {
      rust = {
        enable = lib.mkEnableOption "Ambiente de desenvolvimento Rust";
      };

      python = {
        enable = lib.mkEnableOption "Ambiente de desenvolvimento Python";
      };

      javascript = {
        enable = lib.mkEnableOption "Desenvolvimento JavaScript/TypeScript";
      };

      go = {
        enable = lib.mkEnableOption "Ambiente de desenvolvimento Go";
      };

      nix = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Ferramentas de desenvolvimento Nix (sempre útil no NixOS)";
        };
      };

      c = {
        enable = lib.mkEnableOption "Ambiente de desenvolvimento C/C++";
      };

      java = {
        enable = lib.mkEnableOption "Ambiente de desenvolvimento Java";
      };
    };

    editors = {
      neovim = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Editor Neovim";
        };
      };
    };

    tools = {
      direnv = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Habilita direnv (ambientes por diretório)";
        };
      };

      kubernetes = {
        enable = lib.mkEnableOption "Ferramentas Kubernetes (kubectl, k9s, helm)";
      };

      terraform = {
        enable = lib.mkEnableOption "Terraform e ferramentas relacionadas";
      };

      ansible = {
        enable = lib.mkEnableOption "Gerenciamento de configuração com Ansible";
      };

      arduino = {
        enable = lib.mkEnableOption "Toolchain Arduino (IDE, CLI, serial e PlatformIO)";
      };

      wine = {
        enable = lib.mkEnableOption "Ambiente Wine para aplicativos Windows";
      };

      psim = {
        enable = lib.mkEnableOption "Helpers para rodar o PSIM via Wine";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.tools.psim.enable -> cfg.tools.wine.enable;
        message = "kryonix.features.development.tools.psim.enable exige kryonix.features.development.tools.wine.enable.";
      }
    ];

    # =========================
    # Git
    # =========================
    programs.git = lib.mkIf cfg.git.enable {
      enable = true;
      lfs.enable = true;
    };

    # =========================
    # Direnv
    # =========================
    programs.direnv = lib.mkIf cfg.tools.direnv.enable {
      enable = true;
      nix-direnv.enable = true;
      silent = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
    };

    # =========================
    # System Packages
    # =========================
    environment.systemPackages =
      with pkgs;
      lib.flatten [
        # Git tools
        (lib.optionals cfg.git.enable [
          git
          git-lfs
          gh # GitHub CLI
          lazygit
          gitui
          delta # Better git diff
        ])

        # Editors
        (lib.optional cfg.editors.neovim.enable neovim)

        # Rust
        (lib.optionals cfg.languages.rust.enable [
          rustc
          cargo
          rustfmt
          rust-analyzer
          clippy
        ])

        # Python
        (lib.optionals cfg.languages.python.enable [
          python312
          python312Packages.pip
          python312Packages.virtualenv
          python312Packages.ipython
          ruff # Linter/formatter
          pyright # LSP
        ])

        # JavaScript/TypeScript
        (lib.optionals cfg.languages.javascript.enable [
          nodejs_22
          # npm já vem embutido no nodejs_22.
          yarn
          pnpm
          typescript
          typescript-language-server
          eslint
          prettier
        ])

        # Go
        (lib.optionals cfg.languages.go.enable [
          go
          gopls # LSP
          golangci-lint
          delve # Debugger
        ])

        # Nix
        (lib.optionals cfg.languages.nix.enable [
          nixd # LSP
          nixfmt
          nix-tree
          nix-diff
          nix-output-monitor
          nvd # Nix version diff
        ])

        # C/C++
        (lib.optionals cfg.languages.c.enable [
          gcc
          clang
          cmake
          gnumake
          gdb
          clang-tools # clangd LSP
        ])

        # Java
        (lib.optionals cfg.languages.java.enable [
          jdk21
          maven
          gradle
        ])

        # Kubernetes
        (lib.optionals cfg.tools.kubernetes.enable [
          kubectl
          kubernetes-helm
          k9s
          kubectx
          kustomize
          stern # Multi-pod log tailing
        ])

        # Terraform
        (lib.optionals cfg.tools.terraform.enable [
          terraform
          terraform-ls # LSP
          tflint
          terragrunt
        ])

        # Ansible
        (lib.optionals cfg.tools.ansible.enable [
          ansible
          ansible-lint
        ])

        # Arduino / embarcados
        (lib.optionals cfg.tools.arduino.enable [
          arduino-ide
          arduino-cli
          arduino-language-server
          platformio
          avrdude
          minicom
          picocom
          usbutils
        ])

        # Wine / PSIM
        (lib.optionals cfg.tools.wine.enable [
          winePackage
          winetricks
          bottles
        ])
        (lib.optionals cfg.tools.psim.enable [
          psimPrefixInit
          psimInstall
          psimLauncher
        ])

        # Common dev tools (always included when dev is enabled)
        [
          # Build tools
          gnumake
          cmake
          pkg-config

          # Version control
          mercurial
          subversion

          # Network tools
          curl
          wget
          httpie

          # JSON/YAML tools
          jq
          yq-go

          # File tools
          ripgrep
          fd
          bat
          eza

          # Process tools
          htop
          btop

          # Compression
          unzip
          p7zip

          # Misc
          tree
          tmux
          screen
        ]
      ];

    # =========================
    # Environment Variables
    # =========================
    environment.variables = {
      # Editor
      EDITOR = lib.mkIf cfg.editors.neovim.enable (lib.mkDefault "nvim");
      VISUAL = lib.mkIf cfg.editors.neovim.enable (lib.mkDefault "nvim");

      # Go
      GOPATH = lib.mkIf cfg.languages.go.enable "$HOME/go";

      # Rust
      CARGO_HOME = lib.mkIf cfg.languages.rust.enable "$HOME/.cargo";

      # Arduino / eletrônica
      ARDUINO_DIRECTORIES_USER = lib.mkIf cfg.tools.arduino.enable "$HOME/Arduino";
      PSIM_WINEPREFIX = lib.mkIf cfg.tools.psim.enable "$HOME/${psimPrefixRelative}";
    };

    users.users.${userConfig.name}.extraGroups = lib.mkAfter (
      lib.optionals cfg.tools.arduino.enable [ "dialout" ]
    );

    services.udev.extraRules = lib.mkIf cfg.tools.arduino.enable ''
      # Arduino / USB serial adapters
      SUBSYSTEM=="tty", ATTRS{idVendor}=="2341", MODE="0660", GROUP="dialout", TAG+="uaccess"
      SUBSYSTEM=="tty", ATTRS{idVendor}=="2a03", MODE="0660", GROUP="dialout", TAG+="uaccess"
      SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", MODE="0660", GROUP="dialout", TAG+="uaccess"
      SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", MODE="0660", GROUP="dialout", TAG+="uaccess"
      SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", MODE="0660", GROUP="dialout", TAG+="uaccess"
      SUBSYSTEM=="tty", ATTRS{idVendor}=="04d8", MODE="0660", GROUP="dialout", TAG+="uaccess"
    '';

    # =========================
    # Programs
    # =========================

    # Neovim
    programs.neovim = lib.mkIf cfg.editors.neovim.enable {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
    };

    # =========================
    # Documentation
    # =========================
    documentation = {
      dev.enable = true;
      man.enable = true;
      info.enable = true;
    };
  };
}
