# ==============================================================================
# Módulo: Host Inspiron
# Autor: rag
#
# O que é:
# - Configuração NixOS específica do host `inspiron`.
# - Declara hardware Intel e ajustes de laptop.
#
# Por quê:
# - Mantém separação estrita de hardware por host (sem drivers globais).
# - Facilita manutenção sem impactar outros hosts.
#
# Como:
# - Importa `hardware-configuration.nix` e módulos comuns.
# - Declara stack gráfico Intel localmente neste host.
#
# Riscos:
# - Alterações em boot/kernel/power podem afetar estabilidade e bateria.
# ==============================================================================
{
  inputs,
  hostname,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    # Hardware
    inputs.hardware.nixosModules.common-cpu-intel
    inputs.hardware.nixosModules.common-gpu-intel
    inputs.hardware.nixosModules.common-pc-ssd

    ./hardware-configuration.nix

    # Disko (particionamento declarativo — usado pelo Live CD)
    inputs.disko.nixosModules.disko
    ./disks.nix

    # Desktop: gerenciado via opção (v2 migration)
    # Features: gerenciadas via opções (v2 migration)

    # Kernel e rede
    ../../modules/kernel/zen.nix
    ../../modules/virtualization/net-ragthink.nix

  ];

  # =========================
  # Kryonix Options (v2)
  # =========================

  # Hardware toggles
  kryonix.features.openrgb.enable = false;

  # Desktop

  # Hyprland segue como desktop; Caelestia entra como shell principal de sistema.
  kryonix.desktop.environment = "hyprland";
  kryonix.shell.caelestia.enable = true;
  kryonix.desktop.directLogin.enable = false;

  # Profile (v2)
  kryonix.profiles.laptop = {
    enable = true;

    # Mantém o comportamento atual do inspiron
    virtualization = {
      enable = true;
      docker.enable = false;
      podman.enable = true;
      libvirt.enable = true;
    };

    development.enable = true;

    # Notebook principal: prioriza autonomia e responsividade em vez de stack gamer completo.
    gaming.enable = false;
  };

  # Ajustes específicos além do profile
  kryonix.profiles.dev.enable = true;
  kryonix.profiles.university.enable = true;
  kryonix.profiles.ti.enable = true;

  kryonix.features.development = {
    languages = {
      nix.enable = true;
      python.enable = true;
      javascript.enable = true;
      rust.enable = true;
      c.enable = true;
      java.enable = true;
      go.enable = true;
    };
    tools = {
      kubernetes.enable = true;
      terraform.enable = true;
      ansible.enable = true;
      arduino.enable = true;
    };
  };

  kryonix.features.remoteDesktop.client.enable = true;

  # Kryonix Brain (Distributed Architecture via Tailscale)
  kryonix.features.ai.brain = {
    enable = true;
    role = "client";
    serverHost = "rve-glacier"; # GLACIER (Tailscale Hostname)
  };

  # Kora voice daemon for voice-activated assistant
  kryonix.services.kora.voice = {
    enable = true;
    alwaysOn = true;
  };

  # Garante que o daemon kora-voice-listener sobrevive ao fechamento do terminal.
  users.users.rocha.linger = true;

  networking.hostName = hostname;

  # =========================
  # MikroTik Winbox
  # =========================
  # O que é
  # - Habilita o Winbox (GUI de gerenciamento MikroTik).
  #
  # Por quê
  # - Facilita administrar RouterOS/SwOS direto do desktop.
  #
  # Como
  # - `programs.winbox.enable = true` instala o Winbox.
  programs.winbox.enable = true;

  # UniFi Network Application (Controller).
  # services.unifi = {
  #   enable = true;
  #   openFirewall = true;
  # };

  system.stateVersion = "26.05";

  # =========================
  # Boot / Kernel
  # =========================
  boot = {
    loader = {
      systemd-boot.enable = false;

      grub = {
        enable = true;
        efiSupport = true;
        device = "nodev";
        useOSProber = false;
      };

      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };

    # Flags específicas do hardware/FS deste host.
    kernelParams = lib.mkAfter [
      "rootflags=subvol=@,compress=zstd,noatime"
    ];

    # Usa systemd dentro do initrd para um boot inicial mais consistente.
    initrd.systemd.enable = true;
  };

  # =========================
  # Kernel Zen (ajustado)
  # =========================
  kernelZen = {
    enable = true;

    kernel = "zen";
    forceLocalBuild = false;
    useLLVMStdenv = false;
    extraMakeFlags = [ ];

    # ⚠️ só recomendo isso se for desktop single-user.
    disableMitigations = lib.mkDefault false;

    # Removido: parâmetros agressivos do scheduler podem causar travamentos
    # O kernel Zen já vem otimizado para desktop
    extraKernelParams = [ ];
  };

  # =========================
  # Intel iGPU (Inspiron)
  # =========================
  services.xserver.videoDrivers = [ "modesetting" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver # VA-API iHD (Broadwell+)
      libvdpau-va-gl # VDPAU via VA-API
      intel-vaapi-driver # fallback VA-API i965 (pre-Broadwell)
    ];
  };

  environment.sessionVariables = {
    # Mesa / OpenGL (Intel)
    MESA_LOADER_DRIVER_OVERRIDE = "iris";
    LIBVA_DRIVER_NAME = "iHD";
    # Evita fallback silencioso para software renderer (llvmpipe).
    WLR_RENDERER_ALLOW_SOFTWARE = "0";
  };

  ## -------------------------
  ## Performance básica
  ## -------------------------
  services.power-profiles-daemon.enable = lib.mkForce true;
  services.tlp.enable = lib.mkForce false;

  # Hibernate/hybrid ficam proibidos sempre. Suspend e permitido apenas para
  # politicas user-level controladas, como hypridle somente em bateria.
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "yes";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  services.logind.settings.Login = {
    HandlePowerKey = "ignore";
    HandleSuspendKey = "ignore";
    HandleHibernateKey = "ignore";
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
    IdleAction = "ignore";
  };

  # O zram já estava ativo via common; aqui aumentamos a margem para absorver
  # pressão de memória com mais folga no notebook.
  zramSwap.memoryPercent = lib.mkForce 75;

  # Com 16 GiB + zram, um swappiness mais baixo tende a deixar o desktop mais ágil.
  boot.kernel.sysctl."vm.swappiness" = lib.mkForce 30;

  # Flatpak: mantém a lista comum vinda do módulo shared.
  # (Removemos as extensões NVIDIA do common.)

  environment.systemPackages = with pkgs; [
    kdePackages.kcmutils
    kdePackages.systemsettings
    kdePackages.kde-cli-tools
  ];

  # Gaming/estabilidade: evita serviços que brigam por perfil de energia.
  # (PPD já está habilitado acima; mantemos apenas TLP desligado.)

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="block", KERNEL=="nvme*", ATTR{queue/scheduler}="none"
  '';

  systemd.services = {
    # Essas unidades estão quebradas no estado atual e só poluem o journal/sleep/shutdown.
    pre-sleep.enable = lib.mkForce false;
    pre-shutdown.enable = lib.mkForce false;

  };

  ## -------------------------
  ## Virtualização (ajuste fino)
  ## -------------------------
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModprobeConfig = ''
    options kvm_intel nested=1
  '';

  # =========================
  # Kryonix (branding do sistema)
  # =========================
  # Mantém o mesmo número de versão do seu `system.stateVersion` para exibição.
  # Obs.: `system.stateVersion` continua sendo a chave de compat do NixOS.
  kryonix.branding = {
    enable = true;
    prettyName = "Kryonix";
    versionId = "26.05";
  };

  # =========================
  # Tailscale VPN
  # =========================
  services.kryonix.tailscale = {
    enable = true;
    # O daemon já reconecta sozinho após autenticação; manter o autoconnect
    # bloqueava o boot por ~18s sem ganho prático.
    autoconnect = false;
    authKeyFile = /root/tailscale-authkey.secret;
  };

  # Codex (AI): opt-in via feature pra evitar builds lentos por padrão.
  # Para ativar: kryonix.features.ai.codex.enable = true;
}
