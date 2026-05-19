# ==============================================================================
# Módulo: Base Comum NixOS
# Autor: ragton
#
# O que é:
# - Camada compartilhada entre hosts com defaults de sistema, serviços e pacotes.
# - Ponto único para opções globais não ligadas a hardware específico.
#
# Por quê:
# - Evita duplicação entre hosts.
# - Mantém as configurações por host focadas em hardware e diferenças locais.
#
# Como:
# - Importa módulos compartilhados e define defaults com `mkDefault`.
# - Expõe registry/NIX_PATH e stack base (PipeWire, rede, locale, etc).
#
# Riscos:
# - Qualquer regressão aqui afeta todos os hosts; sempre validar com `nixos-rebuild test`.
# ==============================================================================
{
  inputs,
  outputs,
  lib,
  config,
  userConfig,
  pkgs,
  hostname,
  ...
}:
{
  imports = [
    inputs.nix-flatpak.nixosModules.nix-flatpak
    ../../shared/nixpkgs

    # Branding global (RagOS).
    # Mantemos aqui para que todos os hosts herdem o mesmo "nome do sistema".
    ../branding/ragos

    ../services/tlp
    ../services/greetd-dms
    ../services/snapper
    ../services/tailscale
  ];

  # Registra inputs da flake no registry (melhora UX com comandos `nix ...`).
  nix.registry = lib.mapAttrs (_: flake: { inherit flake; }) (
    lib.filterAttrs (_: lib.isType "flake") inputs
  );

  # Compat: expõe inputs via NIX_PATH (canais legados).
  nix.nixPath = [ "/etc/nix/path" ];
  environment.etc = lib.mapAttrs' (name: value: {
    name = "nix/path/${name}";
    value.source = value.flake;
  }) config.nix.registry;
  # `/etc/ragos` é o checkout Git operacional do sistema. Mantemos `/etc/nixos`
  # apontando para ele por compatibilidade com ferramentas NixOS tradicionais.
  users.groups.ragos = { };
  systemd.tmpfiles.rules = [
    "L+ /etc/nixos - - - - /etc/ragos"
    "d /run/kryonix 0777 root root - -"
  ];

  system.activationScripts.ragosGitRepoPermissions = {
    text = ''
      if [ -L /etc/ragos ]; then
        ${pkgs.coreutils}/bin/chgrp -h ragos /etc/ragos || true
      elif [ -d /etc/ragos ]; then
        ${pkgs.coreutils}/bin/chown -R ${userConfig.name}:ragos /etc/ragos || true
        ${pkgs.findutils}/bin/find /etc/ragos -type d -exec ${pkgs.coreutils}/bin/chmod 2775 {} +
        ${pkgs.findutils}/bin/find /etc/ragos -type f -exec ${pkgs.coreutils}/bin/chmod g+rw {} +
      fi
    '';
  };

  # Nix: ajustes globais.
  nix.package = pkgs.nixVersions.latest;
  nix.settings = {
    experimental-features = "nix-command flakes";
    auto-optimise-store = true;

    # Build paralelo (conservador para evitar travamentos):
    # - max-jobs: máximo de derivations simultâneas
    # - cores: 0 = usa todos os cores disponíveis POR JOB (mas respeitando load)
    # - auto = deixa Nix decidir baseado em RAM/CPU disponíveis
    max-jobs = lib.mkDefault "auto";
    cores = lib.mkDefault 0;
  };

  programs.git = {
    enable = lib.mkDefault true;
    config.safe.directory = "/etc/ragos";
  };

  # Boot: defaults genéricos de silêncio/recovery.
  # Flags de hardware ficam nos hosts; flags do Zen ficam no módulo do kernel.
  boot = {
    consoleLogLevel = lib.mkDefault 3;
    initrd.verbose = lib.mkDefault false;
    kernelParams = lib.mkBefore [
      "quiet"
      "rd.udev.log_level=3"
      "systemd.show_status=auto"
      "rd.systemd.show_status=auto"
      "vt.global_cursor_default=0"
    ];
    loader = {
      timeout = lib.mkDefault 3;
      efi.canTouchEfiVariables = lib.mkDefault true;
    };
    # loader.systemd-boot.enable = false;
    #    loader.systemd-boot.extraFiles =
    #     let
    #      splashSrc = ../../../files/wallpaper/wallpaper.png;
    #     splashBmp = pkgs.runCommand "systemd-boot-splash.bmp" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    #      convert "${splashSrc}" \
    #       -alpha off \
    #      -resize 1920x1080^ \
    #     -gravity center \
    #    -extent 1920x1080 \
    #   BMP3:"$out"
    # '';
    #in
    # {
    #   "loader/splash.bmp" = splashBmp;
    # };
    #loader.timeout = 0;
    plymouth = {
      enable = lib.mkDefault true;
      theme = lib.mkDefault "nixos-bgrt";
      themePackages = lib.mkDefault [ pkgs.nixos-bgrt-plymouth ];
    };

    # Ajustes do módulo v4l (câmera virtual)
    kernelModules = [ "v4l2loopback" ];
    extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
    extraModprobeConfig = ''
      options v4l2loopback exclusive_caps=1 card_label="Virtual Camera"
    '';

    # Tuning balanceado para desktop/games (evita OOM e travamentos).
    kernel.sysctl = {
      # swappiness 60 = padrão Linux, balanceado entre RAM e swap
      # Valor muito baixo pode causar OOM kills e travamentos
      "vm.swappiness" = lib.mkDefault 60;

      # Proteção contra OOM: permite usar mais swap antes de matar processos
      "vm.vfs_cache_pressure" = lib.mkDefault 50;
      "vm.dirty_ratio" = lib.mkDefault 10;
      "vm.dirty_background_ratio" = lib.mkDefault 5;
    };
  };

  # Mitigação prática contra travamentos por pressão de memória.
  # Swap já existe no host, mas zram tende a melhorar muito a responsividade.
  zramSwap = {
    enable = lib.mkDefault true;
    algorithm = lib.mkDefault "zstd";
    # 50% é mais conservador e trabalha melhor com swap em disco
    # Evita pressão excessiva quando a RAM está cheia
    memoryPercent = lib.mkDefault 50;
    # Prioridade alta: tenta usar zram antes do swap em disco
    priority = lib.mkDefault 10;
  };

  # earlyoom: proteção crítica contra travamentos por OOM
  # Mata processos ANTES do sistema travar completamente
  services.earlyoom = {
    enable = lib.mkDefault true;
    enableNotifications = lib.mkDefault true;
    # Mata processos quando RAM livre < 5% E swap livre < 5%
    freeMemThreshold = lib.mkDefault 5;
    freeSwapThreshold = lib.mkDefault 5;
    # Evita matar processos críticos do sistema
    extraArgs = [
      "--avoid"
      "^(Xorg|Hyprland|gdm)$"
      "--prefer"
      "^(firefox|chromium|chrome|electron)$"
    ];
  };

  # Rede
  networking.networkmanager.enable = true;
  networking.hostName = lib.mkDefault hostname;
  networking.firewall = {
    enable = lib.mkDefault true;
    allowedTCPPorts = [
      21115
      21116
      21117
      21118
      21119 # RustDesk
      6568
      7070 # AnyDesk
    ];
    allowedUDPPorts = [
      21116 # RustDesk
      7070 # AnyDesk
    ];
  };

  # Desabilita serviços systemd que impactam o boot
  systemd.services = lib.mkMerge [
    {
      NetworkManager-wait-online.enable = false;
    }
    (lib.mkIf (!config.boot.plymouth.enable) {
      plymouth-quit-wait.enable = false;
      plymouth-quit.enable = false;
      plymouth-start.enable = false;
    })
  ];

  # Fuso horário
  time.timeZone = "America/Cuiaba";

  # Internacionalização
  i18n.defaultLocale = "pt_BR.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "pt_BR.UTF-8";
    LC_IDENTIFICATION = "pt_BR.UTF-8";
    LC_MEASUREMENT = "pt_BR.UTF-8";
    LC_MONETARY = "pt_BR.UTF-8";
    LC_NAME = "pt_BR.UTF-8";
    LC_NUMERIC = "pt_BR.UTF-8";
    LC_PAPER = "pt_BR.UTF-8";
    LC_TELEPHONE = "pt_BR.UTF-8";
    LC_TIME = "pt_BR.UTF-8";
  };

  # Teclado no console virtual (TTY) — layout ABNT2 brasileiro
  console.keyMap = "br-abnt2";

  # Habilita suporte a Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;

    # BlueZ: ajustes para melhorar compatibilidade/qualidade (BT audio)
    # - Experimental habilita suporte a recursos/códigos mais novos quando disponíveis.
    # - Manter como mkDefault para facilitar override.
    settings = {
      General = {
        Name = lib.mkDefault hostname;
        Alias = lib.mkDefault hostname;
        Experimental = lib.mkDefault true;
      };
    };
  };

  # Base para gerenciamento de cor/ICC (útil para HDR/WCG quando suportado)
  services.colord.enable = lib.mkDefault true;
  # Necessário para integração de bateria/energia em apps Wayland da sessão.
  services.upower.enable = lib.mkDefault true;

  # Ajustes de entrada
  services.libinput.enable = true;
  services.logind.settings.Login = {
    KillUserProcesses = lib.mkDefault false;
    HandleLidSwitch = lib.mkDefault "suspend";
    HandleLidSwitchExternalPower = lib.mkDefault "ignore";
    HandleLidSwitchDocked = lib.mkDefault "ignore";
  };

  # Evita troca inesperada de implementação do D-Bus durante `nixos-rebuild test/switch`.
  # (Isso costuma disparar o pre-switch check `switchInhibitors`.)
  services.dbus.implementation = lib.mkDefault "broker";

  # Ajustes do Xserver
  services.xserver = {
    xkb.layout = "br";
    xkb.variant = "abnt2";
    excludePackages = with pkgs; [ xterm ];
  };

  # Habilita Wayland no Chromium/Electron
  # Remove decorações em apps Qt
  # Define tamanho do cursor
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    XCURSOR_SIZE = "24";
  };

  # Configuração de PATH
  environment.localBinInPath = true;

  # Carteira de senhas padrão do projeto: GNOME Keyring via PAM + Secret Service.
  # O foco público do repo é Hyprland + GDM, então não mantemos mais branch de KDE/KWallet aqui.
  services.gnome.gnome-keyring.enable = lib.mkDefault true;
  services.gnome.gcr-ssh-agent.enable = lib.mkDefault false;
  programs.seahorse.enable = lib.mkDefault true;

  # Habilita impressão via CUPS
  services.printing.enable = true;

  # devmon depende de udevil, que frequentemente quebra build em toolchains novos.
  # No stack Hyprland/GDM, o fluxo recomendado para dispositivos removíveis é via udisks2 + gvfs.
  services.devmon.enable = lib.mkDefault false;
  services.udisks2.enable = lib.mkDefault true;
  services.gvfs.enable = lib.mkDefault true;

  # Flatpak (sistema) + gerenciamento declarativo via nix-flatpak
  services.flatpak = {
    enable = true;

    packages = lib.mkDefault [
      "app.zen_browser.zen"
      "io.github.shonebinu.Brief"
      "com.anydesk.Anydesk"
      "com.rustdesk.RustDesk"
      "com.ranfdev.DistroShelf"
      "com.github.tchx84.Flatseal"
      "io.github.flattool.Warehouse"
      "com.rtosta.zapzap"
      "org.gimp.GIMP"
    ];

    uninstallUnmanaged = true;
    update.auto.enable = true;
  };

  # Portal XDG para integração de apps (Flatpak, etc.)
  xdg.portal = {
    enable = true;
  };

  # Configuração do usuário
  users.mutableUsers = true;

  # Este repositório público não publica senha bootstrap para root.
  # Defina manualmente durante a instalação ou injete um hash fora do repo.

  users.users.${userConfig.name} = {
    description = userConfig.fullName;
    extraGroups = [
      "networkmanager"
      "ragos"
      "wheel"
    ]
    ++ lib.optionals config.programs.wireshark.enable [ "wireshark" ];
    isNormalUser = true;
    shell = pkgs.zsh;
  }
  // lib.optionalAttrs (userConfig ? initialHashedPassword) {
    initialHashedPassword = lib.mkDefault userConfig.initialHashedPassword;
  }
  // lib.optionalAttrs (userConfig ? hashedPassword) {
    hashedPassword = lib.mkDefault userConfig.hashedPassword;
  }
  // lib.optionalAttrs (userConfig ? hashedPasswordFile) {
    hashedPasswordFile = lib.mkDefault userConfig.hashedPasswordFile;
  };

  # Define o avatar do usuário
  system.activationScripts.script.text = ''
    mkdir -p /var/lib/AccountsService/{icons,users}
    cp ${userConfig.avatar} /var/lib/AccountsService/icons/${userConfig.name}

    touch /var/lib/AccountsService/users/${userConfig.name}

    if ! grep -q "^Icon=" /var/lib/AccountsService/users/${userConfig.name}; then
      if ! grep -q "^\[User\]" /var/lib/AccountsService/users/${userConfig.name}; then
        echo "[User]" >> /var/lib/AccountsService/users/${userConfig.name}
      fi
      echo "Icon=/var/lib/AccountsService/icons/${userConfig.name}" >> /var/lib/AccountsService/users/${userConfig.name}
    fi
  '';

  # Sudo sem senha
  security.sudo.wheelNeedsPassword = false;

  # Pacotes do sistema
  environment.systemPackages =
    with pkgs;
    [
      gcc
      glib
      gnumake
      nodejs_20
      killall
      mesa
      podman
      distrobox
      nh
      home-manager

      # =========================
      # Python (global)
      # =========================
      # PyCharm/IntelliJ (GUI) frequentemente não herda PATH do Home Manager.
      # Expor o interpretador via systemPackages garante:
      # - /run/current-system/sw/bin/python3
      # - criação de venv por projeto via `python3 -m venv .venv`
      python3
      python3Packages.pip
      python3Packages.virtualenv
      # uv: package manager rápido para Python (também fornece uvx para executar CLIs)
      uv

      # Rust (global): `rustup` gerencia toolchains; `cargo`/`rustc` úteis para uso imediato.
      rustup
      cargo
      rustc

      # =========================
      # Java (global)
      # =========================
      # JDK para apps Java (TLauncher, Minecraft, etc.)
      # jdk21 é LTS e compatível com a maioria dos apps modernos
      jdk21

      jetbrains.idea-oss
      jetbrains.pycharm-oss
      jetbrains.rust-rover

      # RustDesk via Flatpak: evita builds locais pesados do pacote RustDesk
      # nativo e mantém um comando previsível para terminal/scripts.
      (writeShellApplication {
        name = "rustdesk";
        runtimeInputs = [ flatpak ];
        text = ''
          exec flatpak run com.rustdesk.RustDesk "$@"
        '';
      })

      # Ferramentas KDE úteis sem precisar do Plasma completo.
      kdePackages.dolphin
      kdePackages.dolphin-plugins
      kdePackages.kio-extras
      kdePackages.ark
      kdePackages.filelight

      (writeShellApplication {
        name = "keditfiletype";
        text = ''
          set -euo pipefail

          real_kedit="${pkgs.kdePackages."kde-cli-tools"}/bin/keditfiletype"
          if [ -x "$real_kedit" ]; then
            exec "$real_kedit" "$@"
          fi

          exec ${pkgs.kdePackages.systemsettings}/bin/systemsettings "$@"
        '';
      })
    ]
    ++ lib.optionals (builtins.hasAttr "kio-admin" pkgs.kdePackages) [ pkgs.kdePackages."kio-admin" ]
    ++ lib.optionals (builtins.hasAttr "kio-gdrive" pkgs.kdePackages) [ pkgs.kdePackages."kio-gdrive" ]
    ++ [
    ];

  # Rustup: evita o estado "rustup instalado, mas sem toolchain default".
  # Faz bootstrap no primeiro rebuild (e mantém idempotente).
  system.activationScripts.rustupBootstrap = {
    text = ''
      USER=${lib.escapeShellArg userConfig.name}
      HOME_DIR=${
        lib.escapeShellArg (config.users.users.${userConfig.name}.home or "/home/${userConfig.name}")
      }

      if [ -d "$HOME_DIR" ]; then
        # Só roda se rustup existir no sistema
        if command -v rustup >/dev/null 2>&1; then
          # Rodamos como o usuário pra evitar permissões erradas em ~/.rustup e ~/.cargo
          ${pkgs.su}/bin/su - ${userConfig.name} -c ${lib.escapeShellArg ''
            set -euo pipefail
            export HOME="$HOME_DIR"

            # Se não existe toolchain default, instala/define stable.
            if ! rustup show active-toolchain >/dev/null 2>&1; then
              rustup toolchain install stable
              rustup default stable
            fi
          ''}
        fi
      fi
    '';
  };

  # Configuração comum de containers
  # Nota: não habilitamos `podman.dockerCompat` por padrão porque conflita com
  # `virtualisation.docker` quando Docker também está ativo.
  # Deixe isso ser controlado pelo módulo de features (rag.features.virtualization.*)
  # ou por-host.
  virtualisation = {
    containers.enable = true;
    podman = {
      enable = true;
      dockerCompat = lib.mkDefault false;
      dockerSocket.enable = lib.mkDefault false;
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  # Habilita xwayland
  programs.xwayland.enable = true;

  # Configuração do Zsh
  programs.zsh.enable = true;

  # Winbox (MikroTik): o nixpkgs já fornece `programs.winbox`.
  # Habilite por-host (ex.: `hosts/inspiron/default.nix`) com `programs.winbox.enable = true`.

  # Permite carregar binários fora do Nix com GLIBC/linker compatível (útil p/ plugins JetBrains/VSCode)
  programs.nix-ld.enable = true;

  # Configuração de fontes
  fonts = {
    packages = with pkgs; [
      monocraft
      nerd-fonts.jetbrains-mono
      nerd-fonts.meslo-lg
      nerd-fonts.caskaydia-cove
      iosevka
      roboto
      noto-fonts-color-emoji
    ];

    fontconfig.defaultFonts = {
      serif = [ "Monocraft" ];
      sansSerif = [ "Monocraft" ];
      monospace = [ "Monocraft" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  # Serviços adicionais
  services.locate.enable = true;

  # Daemon OpenSSH
  services.openssh.enable = true;
}
