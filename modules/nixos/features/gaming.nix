# =============================================================================
# Feature: Gaming Stack
# Autor: rag (via AI Maintainer)
#
# O que é:
# - Configuração completa para gaming no NixOS
# - Steam, Lutris, GameMode, optimizações de performance
#
# Por quê:
# - Centraliza toda configuração de gaming em um módulo
# - Ativa/desativa facilmente: kryonix.features.gaming.enable = true
# - Mantém hosts limpos
#
# Como usar:
# No host: kryonix.features.gaming.enable = true;
#
# Riscos:
# - Configurações de kernel/drivers são hardware-specific
# - Validar após habilitar em novo hardware
# =============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.kryonix.features.gaming;
  isNvidia =
    (config.hardware.nvidia.enabled or false)
    || lib.elem "nvidia" (config.services.xserver.videoDrivers or [ ]);

in
{
  options.kryonix.features.gaming = {
    enable = lib.mkEnableOption "Stack de gaming (Steam, Lutris, GameMode, etc)";

    steam = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Habilita Steam";
      };

      gamescope = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Habilita a sessão GameScope do Steam";
      };
    };

    lutris = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Habilita Lutris. Desligado por padrão para não puxar Wine/i686 no build base.";
      };
    };

    wineTools = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Habilita ferramentas Wine/Proton fora do Steam (protontricks, DXVK, VKD3D e afins).";
      };
    };

    heroic = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Habilita Heroic Games Launcher (Epic/GOG)";
      };
    };

    gamemode = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Habilita GameMode (otimizações de performance)";
      };
    };

    mangohud = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Habilita MangoHud (overlay de FPS)";
      };
    };

    nvtop = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Habilita nvtop para NVIDIA. Desligado por padrão porque puxa o CUDA toolkit completo.";
      };
    };

    sunshine = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Habilita Sunshine (servidor de game streaming)";
      };
    };

    performanceGovernor = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Define o governor de CPU como performance durante jogos";
    };
  };

  config = lib.mkIf cfg.enable {
    # =========================
    # Steam
    # =========================
    programs.steam = lib.mkIf cfg.steam.enable {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;

      protontricks.enable = cfg.wineTools.enable;
      gamescopeSession.enable = cfg.steam.gamescope;

      extraCompatPackages = lib.optional (pkgs ? proton-ge-bin) pkgs.proton-ge-bin;
    };
    hardware.steam-hardware.enable = lib.mkIf cfg.steam.enable true;

    # =========================
    # GameMode
    # =========================
    programs.gamemode = lib.mkIf cfg.gamemode.enable {
      enable = true;

      settings = {
        general = {
          renice = 10;
          desiredgov = "performance";
          softrealtime = "auto";
          inhibit_screensaver = 1;
        };

        cpu = {
          park_cores = "no";
          pin_cores = "no";
        };
      };
    };

    # =========================
    # System Packages
    # =========================
    environment.systemPackages =
      with pkgs;
      lib.flatten [
        (lib.optional cfg.mangohud.enable mangohud)
        (lib.optional cfg.lutris.enable lutris)
        (lib.optional cfg.heroic.enable heroic)
        (lib.optional cfg.sunshine.enable sunshine)
        (lib.optional (pkgs ? atlauncher) atlauncher)
        (lib.optional (pkgs ? moonlight-qt) moonlight-qt)
        (lib.optional (pkgs ? gamescope) gamescope)
        (lib.optional (pkgs ? vkbasalt) vkbasalt)
        (lib.optional (pkgs ? vulkan-tools) vulkan-tools)
        (lib.optional (pkgs ? mesa-demos) mesa-demos)
        (lib.optional (cfg.wineTools.enable && pkgs ? umu-launcher) umu-launcher)
        (lib.optional (cfg.wineTools.enable && pkgs ? protonup-qt) protonup-qt)
        (lib.optional (cfg.wineTools.enable && pkgs ? protontricks) protontricks)
        (lib.optional (cfg.wineTools.enable && pkgs ? dxvk) dxvk)
        (lib.optional (cfg.wineTools.enable && pkgs ? vkd3d-proton) vkd3d-proton)
        (lib.optional (
          cfg.nvtop.enable && isNvidia && pkgs ? nvtopPackages && pkgs.nvtopPackages ? nvidia
        ) pkgs.nvtopPackages.nvidia)
      ];

    # =========================
    # Performance Optimizations
    # =========================

    # CPU Governor
    powerManagement.cpuFreqGovernor = lib.mkIf cfg.performanceGovernor "performance";

    # Kernel parameters (gaming-friendly)
    boot.kernel.sysctl = {
      # Increase inotify watches (helps with large game libraries)
      "fs.inotify.max_user_watches" = 524288;

      # Network optimizations for online gaming
      "net.ipv4.tcp_congestion_control" = "bbr";
      "net.core.default_qdisc" = "fq";

      # Reduce swappiness (prefer RAM for games)
      "vm.swappiness" = 10;
    };

    # =========================
    # Graphics
    # =========================

    hardware.graphics.enable = lib.mkDefault true;
    hardware.graphics.enable32Bit = lib.mkDefault true;

    # =========================
    # Firewall (game streaming)
    # =========================
    networking.firewall = lib.mkIf cfg.sunshine.enable {
      allowedTCPPorts = [
        47984
        47989
        48010
      ];
      allowedUDPPorts = [
        47998
        47999
        48000
        48010
      ];
    };

    # =========================
    # Udev Rules
    # =========================
    services.udev.extraRules = ''
      # PlayStation Controllers
      SUBSYSTEM=="usb", ATTRS{idVendor}=="054c", MODE="0666"

      # Xbox Controllers
      SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", MODE="0666"

      # Nintendo Switch Pro Controller
      SUBSYSTEM=="usb", ATTRS{idVendor}=="057e", MODE="0666"
    '';

    # =========================
    # Assertions
    # =========================
    assertions = [
      {
        assertion = cfg.steam.gamescope -> cfg.steam.enable;
        message = "GameScope requer que o Steam esteja habilitado";
      }
    ];
  };
}
