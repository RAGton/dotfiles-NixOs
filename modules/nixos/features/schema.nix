# =============================================================================
# Module: Feature Schema — namespace público kryonix.features.*
# Autor: Gabriel Rocha (ragton) + Aura
# Data: 2026-06-23
#
# O que é:
# - Declaração do schema público de features do Kryonix.
# - Apenas opções (options), sem implementação (config).
# - Todas as features têm default = false.
# - Este módulo é importado por modules/nixos/features/default.nix.
#
# Por quê:
# - Contrato público entre core (upstream) e downstream (kryonixos).
# - Cada feature é atómica, opt-in e desligada por padrão.
# - Installer e Feature Registry referenciam este schema.
#
# Como:
# - Opções já declaradas em outros módulos (desktop.plasma, gaming.*, etc.)
#   NÃO são repetidas aqui para evitar colisão.
# - Apenas opções GENUINAMENTE NOVAS são declaradas.
# - A implementação (config) virá em PRs futuros.
#
# Riscos:
# - Colisão com opções existentes se namespace não for verificado.
# - Nenhum porque este módulo só declara options, não ativa nada.
# =============================================================================
{ lib, ... }:

{
  options.kryonix.features = {
    # =========================
    # Base system
    # =========================
    base = {
      enable = lib.mkEnableOption "Base system configuration (Nix settings, locale, registry)";
    };

    # =========================
    # Desktop environments
    # =========================
    desktop = {
      hyprland = {
        enable = lib.mkEnableOption "Hyprland compositor (legacy/coexistence)";
      };
    };

    # =========================
    # Hardware profiles
    # =========================
    hardware = {
      laptop = {
        enable = lib.mkEnableOption "Laptop hardware profile (TLP, battery, thermald, power management)";
      };

      sensors = {
        enable = lib.mkEnableOption "Hardware sensors monitoring (lm-sensors, hddtemp)";
      };
    };

    # =========================
    # GPU drivers
    # =========================
    gpu = {
      intel = {
        enable = lib.mkEnableOption "Intel GPU drivers (i915, VAAPI, media driver)";
      };

      amd = {
        enable = lib.mkEnableOption "AMD GPU drivers (amdgpu, ROCm)";
      };

      nvidia = {
        enable = lib.mkEnableOption "NVIDIA proprietary driver (nvidia, nvidia-utils, prime)";
      };

      cuda = {
        enable = lib.mkEnableOption "CUDA toolkit and GPU compute support";
      };
    };

    # =========================
    # Kernel variants
    # =========================
    kernel = {
      zen = {
        enable = lib.mkEnableOption "Linux Zen kernel (desktop/gaming optimized)";
      };

      hardened = {
        enable = lib.mkEnableOption "Linux Hardened kernel (security-focused)";
      };

      lowLatency = {
        enable = lib.mkEnableOption "Linux Low-Latency kernel (audio production)";
      };
    };

    # =========================
    # Network
    # =========================
    network = {
      tailscale = {
        enable = lib.mkEnableOption "Tailscale mesh VPN (Zero-config VPN)";
      };

      bridge = {
        enable = lib.mkEnableOption "Network bridge (br0) for VMs and containers";
      };

      vlan = {
        enable = lib.mkEnableOption "VLAN support and tagging";
      };

      firewall = {
        strict = {
          enable = lib.mkEnableOption "Strict firewall (default deny, explicit allow)";
        };
      };
    };

    # =========================
    # Remote access
    # =========================
    remote = {
      ssh = {
        enable = lib.mkEnableOption "OpenSSH server daemon";
      };

      desktop = {
        client = {
          enable = lib.mkEnableOption "Remote desktop client tools (TigerVNC, KRDC)";
        };

        server = {
          enable = lib.mkEnableOption "Remote desktop server (VNC/WayVNC/KRDP)";
        };
      };
    };

    # =========================
    # Development — editors
    # =========================
    development = {
    };

    # =========================
    # Virtualization
    # =========================
    virtualization = {
      proxmoxLike = {
        enable = lib.mkEnableOption "Proxmox-like virtualization stack (bridge + libvirt + ZFS + firewall strict)";
      };
    };

    # =========================
    # AI / Brain
    # =========================
    ai = {
      brain = {
        client = {
          enable = lib.mkEnableOption "Kryonix Brain client mode (connects to remote Brain server)";

          serverAddress = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1";
            description = "Endereço ou IP do servidor Brain (ex: hostname ou IP Tailscale)";
          };
        };

        server = {
          enable = lib.mkEnableOption "Kryonix Brain server mode (hosts Ollama, LightRAG, Neo4j)";
        };
      };
    };

    # =========================
    # Server
    # =========================
    server = {
      enable = lib.mkEnableOption "Server mode umbrella (containers, database, reverse proxy, backups)";
    };
  };
}
