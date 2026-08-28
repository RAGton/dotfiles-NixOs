# =============================================================================
# Feature: Virtualization Stack
# Autor: rag (via AI Maintainer)
#
# O que é:
# - Configuração completa para virtualização (KVM, libvirt, virt-manager)
# - Docker, Podman, LXC
#
# Por quê:
# - Centraliza toda configuração de virtualização
# - Ativa/desativa facilmente: kryonix.features.virtualization.enable = true
# - Suporta múltiplos backends
#
# Como usar:
# No host: kryonix.features.virtualization.enable = true;
#
# Riscos:
# - Requer CPU com suporte a virtualização (Intel VT-x / AMD-V)
# - Pode conflitar com outros hypervisors (VirtualBox, etc)
# =============================================================================
{
  config,
  lib,
  pkgs,
  userConfig,
  ...
}:

let
  cfg = config.kryonix.features.virtualization;

in
{
  options.kryonix.features.virtualization = {
    enable = lib.mkEnableOption "Stack de virtualização";

    kvm = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Habilita virtualização KVM/QEMU";
      };
    };

    libvirt = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Habilita libvirt (virt-manager, virsh)";
      };
    };

    docker = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Habilita Docker. Desligado por padrão neste repo; preferimos Podman.";
      };

      rootless = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Executa Docker em modo rootless";
      };
    };

    incus = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Habilita Incus daemon (containers e VMs)";
      };

      ui = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Habilita Incus Web UI";
        };
      };

      socketActivation = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Usa socket activation para o Incus";
      };

      preseed = lib.mkOption {
        type = lib.types.nullOr lib.types.lines;
        default = null;
        description = "Configuração preseed YAML para o Incus (storage, rede, etc)";
      };

      storage = {
        backend = lib.mkOption {
          type = lib.types.str;
          default = "zfs";
          description = "Backend de storage do Incus";
        };
        poolName = lib.mkOption {
          type = lib.types.str;
          default = "kryonix-incus";
          description = "Nome da pool do Incus";
        };
        source = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "glacier-data/incus-storage";
          description = "Dataset/device fonte para o storage do Incus";
        };
      };

      network = {
        mode = lib.mkOption {
          type = lib.types.str;
          default = "managed-nat";
          description = "Modo de rede do Incus";
        };
        bridgeName = lib.mkOption {
          type = lib.types.str;
          default = "incusbr-kryonix";
          description = "Nome da interface de bridge do Incus";
        };
      };
    };

    podman = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Habilita Podman como backend de containers preferido do projeto";
      };

      dockerCompat = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Habilita compatibilidade com Docker (podman-docker)";
      };
    };

    lxc = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Habilita containers LXC";
      };
    };

    virtualbox = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Habilita VirtualBox (pode conflitar com KVM)";
      };
    };

  };

  config = lib.mkIf cfg.enable {
    # =========================
    # KVM/QEMU
    # =========================
    virtualisation.libvirtd = lib.mkIf (cfg.kvm.enable && cfg.libvirt.enable) {
      enable = true;

      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;
        # NOTE: `virtualisation.libvirtd.qemu.ovmf` submodule was removed upstream.
        # All OVMF images distributed with QEMU are available by default now.
        # If you need SecureBoot/TPM variants explicitly, set qemu.swtpm/firmware
        # through the new upstream options.
      };
    };

    programs.virt-manager = lib.mkIf (cfg.kvm.enable && cfg.libvirt.enable) {
      enable = true;
    };

    # Polkit: permite gestão do libvirt (virsh / virt-manager) sem senha para usuários no grupo libvirtd
    security.polkit.extraConfig = lib.mkIf (cfg.kvm.enable && cfg.libvirt.enable) ''
      polkit.addRule(function(action, subject) {
        if (action.id.indexOf("org.libvirt.unix.") === 0 && subject.isInGroup("libvirtd")) {
          return polkit.Result.YES;
        }
      });
    '';

    # =========================
    # Docker
    # =========================
    virtualisation.docker = lib.mkIf cfg.docker.enable {
      enable = true;
      enableOnBoot = true;

      # Rootless mode
      rootless = lib.mkIf cfg.docker.rootless {
        enable = true;
        setSocketVariable = true;
      };

      # Storage driver
      storageDriver = "overlay2";

      # Auto-prune
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };

    # =========================
    # Incus
    # =========================
    virtualisation.incus = lib.mkIf cfg.incus.enable {
      enable = true;
      ui.enable = cfg.incus.ui.enable;
      socketActivation = cfg.incus.socketActivation;
      # Habilitar se fornecido
      preseed = lib.mkIf (cfg.incus.preseed != null) cfg.incus.preseed;
    };

    # Garante que o endpoint HTTPS da Web UI do Incus escute de forma declarativa e canônica
    systemd.services.incus-webui-setup = lib.mkIf (cfg.incus.enable && cfg.incus.ui.enable) {
      description = "Configuração canônica e declarativa do endpoint HTTPS da Incus Web UI (:8443)";
      after = [ "incus.service" ];
      wants = [ "incus.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.incus}/bin/incus config set core.https_address :8443";
      };
    };

    # =========================
    # Podman
    # =========================
    virtualisation.podman = lib.mkIf cfg.podman.enable {
      enable = true;

      # Docker compatibility
      dockerCompat = cfg.podman.dockerCompat;
      dockerSocket.enable = true;

      # Default network
      defaultNetwork.settings.dns_enabled = true;

      # Auto-update
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };

    # =========================
    # LXC
    # =========================
    virtualisation.lxc = lib.mkIf cfg.lxc.enable {
      enable = true;
      lxcfs.enable = true;
    };

    # =========================
    # VirtualBox
    # =========================
    virtualisation.virtualbox.host = lib.mkIf cfg.virtualbox.enable {
      enable = true;
      enableExtensionPack = true;
    };

    # =========================
    # System Packages
    # =========================
    environment.systemPackages =
      with pkgs;
      lib.flatten [
        # KVM/QEMU tools
        (lib.optionals (cfg.kvm.enable && cfg.libvirt.enable) [
          virt-viewer
          virtiofsd
          spice
          spice-gtk
          spice-protocol
          virtio-win
          win-spice
        ])

        # Docker tools
        (lib.optionals cfg.docker.enable [
          docker-compose
          lazydocker
        ])

        # Podman tools
        (
          lib.optionals cfg.podman.enable [
            podman-compose
            podman-tui
          ]
          ++ lib.optionals (builtins.hasAttr "podman-desktop" pkgs) [
            pkgs.podman-desktop
          ]
        )

        # LXC tools
        (lib.optionals cfg.lxc.enable [
          lxc
        ])

        # Incus tools
        (lib.optionals cfg.incus.enable [
          incus
        ])
      ];

    # =========================
    # User Groups
    # =========================
    # Add user to virtualization groups.
    # `userConfig` chega via specialArgs do flake, então usamos diretamente aqui.
    users.users.${userConfig.name}.extraGroups = lib.mkAfter (
      lib.flatten [
        (lib.optionals (cfg.kvm.enable && cfg.libvirt.enable) [
          "libvirtd"
          "kvm"
        ])
        (lib.optional cfg.docker.enable "docker")
        (lib.optional cfg.podman.enable "podman")
        (lib.optional cfg.lxc.enable "lxc")
        (lib.optional cfg.virtualbox.enable "vboxusers")
        (lib.optional cfg.incus.enable "incus-admin")
      ]
    );

    # =========================
    # Networking (libvirt)
    # =========================
    networking.firewall = lib.mkIf (cfg.kvm.enable && cfg.libvirt.enable) {
      # Allow libvirt bridge traffic
      # Tipo da opção: boolean ou "strict"/"loose". Usamos "loose" como padrão
      # compatível com Tailscale (que também define "loose").
      checkReversePath = lib.mkDefault "loose";
    };

    # =========================
    # Performance
    # =========================
    boot.kernel.sysctl = lib.mkIf cfg.kvm.enable {
      # Huge pages for VMs
      "vm.nr_hugepages" = lib.mkDefault 0; # Adjust per host
    };

    # =========================
    # Kernel Modules
    # =========================
    boot.kernelModules = lib.flatten [
      # KVM Intel/AMD devem ser definidos por host (hardware-specific).
      # Aqui mantemos apenas módulos genéricos de VirtualBox.
      (lib.optionals cfg.virtualbox.enable [
        "vboxdrv"
        "vboxnetadp"
        "vboxnetflt"
      ])
    ];

    # =========================
    # Assertions
    # =========================
    assertions = [
      {
        assertion =
          !(cfg.docker.enable && cfg.docker.rootless && cfg.podman.enable && cfg.podman.dockerCompat);
        message = ''
          Não é possível habilitar Docker rootless e Podman com compatibilidade Docker ao mesmo tempo.
          Escolha apenas um dos dois.
        '';
      }
      {
        assertion = !(cfg.kvm.enable && cfg.virtualbox.enable);
        message = ''
          KVM e VirtualBox podem conflitar. Recomenda-se usar apenas um.
          Se precisar de ambos, certifique-se de que não rodam simultaneamente.
        '';
      }
      {
        assertion = cfg.libvirt.enable -> cfg.kvm.enable;
        message = "libvirt requer que o KVM esteja habilitado";
      }
    ];

    # =========================
    # Warnings
    # =========================
    warnings = lib.flatten [
      (lib.optional (
        cfg.kvm.enable && cfg.virtualbox.enable
      ) "KVM e VirtualBox estão ambos habilitados. Podem conflitar se usados simultaneamente.")

      (lib.optional (
        cfg.docker.enable && cfg.podman.enable
      ) "Docker e Podman estão ambos habilitados. Considere usar apenas um para economizar recursos.")
    ];
  };
}
