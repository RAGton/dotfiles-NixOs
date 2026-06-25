# =============================================================================
# Module: Feature Registry — metadados do catálogo público de features
# Autor: Gabriel Rocha (ragton) + Aura
# Data: 2026-06-23
#
# O que é:
# - Fonte de verdade única para metadados de cada feature do Kryonix.
# - Não declara opções NixOS (options) nem implementa config.
# - Puramente metadata: categorias, riscos, dependências, conflitos, defaults.
#
# Por quê:
# - Installer, downstream e documentação consultam este registry.
# - Evita divergência entre core e installer.
# - Centraliza decisões de UI (installerVisible, risk, category).
#
# Como:
# - Cada entrada representa uma feature atómica.
# - O ID segue o namespace kryonix.features.<categoria>.<nome>.
# - O registry é consumível como lista de attrset para export JSON.
#
# Riscos:
# - Nenhum — registry não ativa nada, só documenta.
# =============================================================================
{ lib, ... }:

let
  # =========================
  # Helper para criar entrada do registry
  # =========================
  mkFeature =
    {
      id,
      label,
      category,
      description ? "",
      risk ? "low",
      default ? false,
      requires ? [ ],
      conflicts ? [ ],
      installerVisible ? true,
      experimental ? false,
      requiresReboot ? false,
      affects ? [ ],
    }:
    {
      inherit
        id
        label
        category
        description
        risk
        default
        requires
        conflicts
        installerVisible
        experimental
        requiresReboot
        affects
        ;
    };
in
{
  # O registry é exposto como option para que o flake possa exportá-lo.
  # Nenhuma implementação (config) — só dados.
  options.kryonix = {
    featureRegistry = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            id = lib.mkOption {
              type = lib.types.str;
              description = "Identificador único da feature (ex: desktop.plasma)";
            };
            label = lib.mkOption {
              type = lib.types.str;
              description = "Nome amigável para UI";
            };
            category = lib.mkOption {
              type = lib.types.str;
              description = "Categoria agrupadora (desktop, gpu, kernel, network, etc)";
            };
            description = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Descrição curta da feature";
            };
            risk = lib.mkOption {
              type = lib.types.enum [
                "low"
                "medium"
                "high"
              ];
              default = "low";
              description = "Risco de ativar a feature";
            };
            default = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Valor padrão (sempre false — opt-in puro)";
            };
            requires = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "IDs de features obrigatórias";
            };
            conflicts = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "IDs de features incompatíveis";
            };
            installerVisible = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Aparece na UI do installer?";
            };
            experimental = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Feature ainda não estável?";
            };
            requiresReboot = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Requer reboot após ativar?";
            };
            affects = lib.mkOption {
              type = lib.types.listOf (
                lib.types.enum [
                  "boot"
                  "desktop"
                  "gpu"
                  "kernel"
                  "network"
                  "security"
                  "ssh"
                  "storage"
                  "virtualization"
                ]
              );
              default = [ ];
              description = "Domínios do sistema afetados por esta feature";
            };
          };
        }
      );
      default = [ ];
      description = "Catálogo público de features do Kryonix (Feature Registry). Fonte de verdade para core, downstream e installer.";
    };
  };

  config = {
    kryonix.featureRegistry = [
      # =====================================================================
      # Base
      # =====================================================================
      (mkFeature {
        id = "base";
        label = "Base System";
        category = "base";
        description = "Configurações base do sistema NixOS (locale, registry, Nix settings)";
        risk = "low";
        installerVisible = false;
        affects = [ ];
      })

      # =====================================================================
      # Desktop
      # =====================================================================
      (mkFeature {
        id = "desktop.plasma";
        label = "KDE Plasma";
        category = "desktop";
        description = "Ambiente gráfico completo KDE Plasma 6 Wayland";
        risk = "medium";
        conflicts = [ "desktop.hyprland" ];
        requires = [ "desktop.audio" ];
        requiresReboot = true;
        affects = [
          "desktop"
          "boot"
        ];
      })

      (mkFeature {
        id = "desktop.hyprland";
        label = "Hyprland";
        category = "desktop";
        description = "Hyprland compositor Wayland (legado/coexistência)";
        risk = "medium";
        conflicts = [ "desktop.plasma" ];
        requires = [ "desktop.audio" ];
        requiresReboot = true;
        affects = [
          "desktop"
          "boot"
        ];
      })

      (mkFeature {
        id = "desktop.audio";
        label = "PipeWire Audio";
        category = "desktop";
        description = "Servidor moderno de áudio para baixa latência";
        risk = "low";
        requiresReboot = true;
        affects = [ "desktop" ];
      })

      (mkFeature {
        id = "desktop.bluetooth";
        label = "Bluetooth";
        category = "desktop";
        description = "Suporte a Bluetooth (bluez, bluetoothctl)";
        risk = "low";
        affects = [ "desktop" ];
      })

      (mkFeature {
        id = "desktop.printing";
        label = "CUPS Printing";
        category = "desktop";
        description = "Serviço de impressão CUPS";
        risk = "low";
        affects = [ "desktop" ];
      })

      # =====================================================================
      # Hardware
      # =====================================================================
      (mkFeature {
        id = "hardware.laptop";
        label = "Laptop Profile";
        category = "hardware";
        description = "Perfil laptop: TLP, bateria, thermald, power management";
        risk = "medium";
        affects = [ "boot" ];
      })

      (mkFeature {
        id = "hardware.sensors";
        label = "Hardware Sensors";
        category = "hardware";
        description = "Monitoramento de sensores (lm-sensors, hddtemp)";
        risk = "low";
        affects = [ ];
      })

      # =====================================================================
      # GPU
      # =====================================================================
      (mkFeature {
        id = "gpu.intel";
        label = "Intel GPU";
        category = "gpu";
        description = "Drivers Intel (i915, VAAPI, intel-media-driver)";
        risk = "low";
        requiresReboot = true;
        affects = [
          "gpu"
          "boot"
        ];
      })

      (mkFeature {
        id = "gpu.amd";
        label = "AMD GPU";
        category = "gpu";
        description = "Drivers AMD (amdgpu, ROCm)";
        risk = "low";
        requiresReboot = true;
        affects = [
          "gpu"
          "boot"
        ];
      })

      (mkFeature {
        id = "gpu.nvidia";
        label = "NVIDIA GPU";
        category = "gpu";
        description = "Driver proprietário NVIDIA (nvidia, nvidia-utils, Prime)";
        risk = "high";
        requiresReboot = true;
        affects = [
          "gpu"
          "boot"
        ];
      })

      (mkFeature {
        id = "gpu.cuda";
        label = "CUDA";
        category = "gpu";
        description = "CUDA toolkit e suporte a GPU compute";
        risk = "medium";
        requires = [ "gpu.nvidia" ];
        requiresReboot = true;
        affects = [ "gpu" ];
      })

      # =====================================================================
      # Kernel
      # =====================================================================
      (mkFeature {
        id = "kernel.zen";
        label = "Linux Zen";
        category = "kernel";
        description = "Kernel Linux Zen (otimizado para desktop/gaming)";
        risk = "medium";
        requiresReboot = true;
        affects = [
          "boot"
          "kernel"
        ];
      })

      (mkFeature {
        id = "kernel.hardened";
        label = "Linux Hardened";
        category = "kernel";
        description = "Kernel Linux Hardened (foco em segurança)";
        risk = "high";
        conflicts = [
          "kernel.zen"
          "kernel.lowLatency"
        ];
        requiresReboot = true;
        affects = [
          "boot"
          "kernel"
          "security"
        ];
      })

      (mkFeature {
        id = "kernel.lowLatency";
        label = "Linux Low-Latency";
        category = "kernel";
        description = "Kernel Linux Low-Latency (produção de áudio)";
        risk = "medium";
        conflicts = [
          "kernel.zen"
          "kernel.hardened"
        ];
        requiresReboot = true;
        affects = [
          "boot"
          "kernel"
        ];
      })

      # =====================================================================
      # Network
      # =====================================================================
      (mkFeature {
        id = "network.tailscale";
        label = "Tailscale";
        category = "network";
        description = "Mesh VPN Zero-config (Tailscale)";
        risk = "low";
        affects = [ "network" ];
      })

      (mkFeature {
        id = "network.bridge";
        label = "Network Bridge";
        category = "network";
        description = "Bridge de rede (br0) para VMs e containers";
        risk = "medium";
        affects = [ "network" ];
      })

      (mkFeature {
        id = "network.vlan";
        label = "VLAN";
        category = "network";
        description = "Suporte a VLAN tagging";
        risk = "medium";
        affects = [ "network" ];
      })

      (mkFeature {
        id = "network.firewall.strict";
        label = "Strict Firewall";
        category = "network";
        description = "Firewall restritivo (negar por padrão, permitir explícito)";
        risk = "high";
        affects = [
          "network"
          "security"
        ];
      })

      # =====================================================================
      # Remote access
      # =====================================================================
      (mkFeature {
        id = "remote.ssh";
        label = "OpenSSH Server";
        category = "remote";
        description = "Servidor OpenSSH para acesso remoto";
        risk = "medium";
        affects = [
          "ssh"
          "security"
        ];
      })

      (mkFeature {
        id = "remote.desktop.client";
        label = "Remote Desktop Client";
        category = "remote";
        description = "Ferramentas cliente de desktop remoto (TigerVNC, KRDC)";
        risk = "low";
        affects = [ ];
      })

      (mkFeature {
        id = "remote.desktop.server";
        label = "Remote Desktop Server";
        category = "remote";
        description = "Servidor de desktop remoto (VNC/WayVNC/KRDP)";
        risk = "medium";
        affects = [
          "network"
          "security"
        ];
      })

      # =====================================================================
      # Development
      # =====================================================================
      (mkFeature {
        id = "development";
        label = "Development";
        category = "development";
        description = "Ambiente de desenvolvimento (Git, editors, LSP)";
        risk = "low";
        affects = [ ];
      })

      (mkFeature {
        id = "development.languages.nix";
        label = "Nix Language";
        category = "development";
        description = "Ferramentas de desenvolvimento Nix";
        risk = "low";
      })

      (mkFeature {
        id = "development.languages.rust";
        label = "Rust Language";
        category = "development";
        description = "Toolchain Rust (rustc, cargo, clippy, rust-analyzer)";
        risk = "low";
      })

      (mkFeature {
        id = "development.languages.python";
        label = "Python Language";
        category = "development";
        description = "Ambiente Python (pip, venv, poetry)";
        risk = "low";
      })

      (mkFeature {
        id = "development.languages.c";
        label = "C/C++ Language";
        category = "development";
        description = "Toolchain C/C++ (gcc, clang, cmake)";
        risk = "low";
      })

      (mkFeature {
        id = "development.languages.go";
        label = "Go Language";
        category = "development";
        description = "Toolchain Go (golang, go tools)";
        risk = "low";
      })

      (mkFeature {
        id = "development.editors.vscode";
        label = "VSCode";
        category = "development";
        description = "Editor Visual Studio Code / VSCodium";
        risk = "low";
      })

      # =====================================================================
      # Virtualization
      # =====================================================================
      (mkFeature {
        id = "virtualization";
        label = "Virtualization";
        category = "virtualization";
        description = "Stack de virtualização (KVM, libvirt, Podman, Docker)";
        risk = "medium";
        affects = [ "virtualization" ];
      })

      (mkFeature {
        id = "virtualization.libvirt";
        label = "libvirt/KVM";
        category = "virtualization";
        description = "Hypervisor KVM/QEMU com libvirt (virt-manager, virsh)";
        risk = "medium";
        requires = [ "virtualization" ];
        requiresReboot = true;
        affects = [
          "virtualization"
          "network"
        ];
      })

      (mkFeature {
        id = "virtualization.podman";
        label = "Podman";
        category = "virtualization";
        description = "Gerenciador de containers Podman";
        risk = "low";
        requires = [ "virtualization" ];
        affects = [ "virtualization" ];
      })

      (mkFeature {
        id = "virtualization.docker";
        label = "Docker";
        category = "virtualization";
        description = "Gerenciador de containers Docker";
        risk = "low";
        requires = [ "virtualization" ];
        affects = [ "virtualization" ];
      })

      (mkFeature {
        id = "virtualization.proxmoxLike";
        label = "Proxmox-like Stack";
        category = "virtualization";
        description = "Stack estilo Proxmox: bridge + libvirt + ZFS + firewall estrito";
        risk = "high";
        requires = [
          "virtualization.libvirt"
          "network.bridge"
        ];
        requiresReboot = true;
        affects = [
          "virtualization"
          "network"
          "storage"
        ];
      })

      # =====================================================================
      # AI / Brain
      # =====================================================================
      (mkFeature {
        id = "ai.brain.client";
        label = "Brain Client";
        category = "ai";
        description = "Cliente do Kryonix Brain (conecta ao servidor remoto)";
        risk = "low";
        affects = [ ];
      })

      (mkFeature {
        id = "ai.brain.server";
        label = "Brain Server";
        category = "ai";
        description = "Servidor do Kryonix Brain (Ollama, LightRAG, Neo4j)";
        risk = "high";
        requires = [ "gpu.cuda" ];
        requiresReboot = true;
        affects = [
          "gpu"
          "storage"
          "network"
        ];
      })

      (mkFeature {
        id = "ai.ollama";
        label = "Ollama";
        category = "ai";
        description = "Motor de inferência local Ollama (LLMs)";
        risk = "medium";
        requires = [ "gpu.cuda" ];
        affects = [
          "gpu"
          "storage"
        ];
      })

      (mkFeature {
        id = "ai.lightrag";
        label = "LightRAG";
        category = "ai";
        description = "Motor de Retrieval-Augmented Generation baseado em grafos";
        risk = "medium";
        requires = [ "ai.ollama" ];
        affects = [ "storage" ];
      })

      (mkFeature {
        id = "ai.neo4j";
        label = "Neo4j";
        category = "ai";
        description = "Banco de dados em grafo Neo4j";
        risk = "medium";
        affects = [ "storage" ];
      })

      # =====================================================================
      # Gaming
      # =====================================================================
      (mkFeature {
        id = "gaming";
        label = "Gaming";
        category = "gaming";
        description = "Stack de gaming (Steam, GameMode, otimizações)";
        risk = "low";
        requires = [ "desktop.audio" ];
        affects = [ "gpu" ];
      })

      (mkFeature {
        id = "gaming.steam";
        label = "Steam";
        category = "gaming";
        description = "Plataforma Steam + GameScope";
        risk = "low";
        requires = [ "gaming" ];
        affects = [ "gpu" ];
      })

      (mkFeature {
        id = "gaming.lutris";
        label = "Lutris";
        category = "gaming";
        description = "Gerenciador de jogos Lutris (Wine/Proton)";
        risk = "low";
        requires = [ "gaming" ];
        affects = [ "gpu" ];
      })

      (mkFeature {
        id = "gaming.gamemode";
        label = "GameMode";
        category = "gaming";
        description = "Otimizações de performance GameMode";
        risk = "low";
        requires = [ "gaming" ];
        affects = [ "gpu" ];
      })

      (mkFeature {
        id = "gaming.mangohud";
        label = "MangoHud";
        category = "gaming";
        description = "Overlay de FPS MangoHud";
        risk = "low";
        requires = [ "gaming" ];
        affects = [ "gpu" ];
      })

      # =====================================================================
      # Server
      # =====================================================================
      (mkFeature {
        id = "server";
        label = "Server Mode";
        category = "server";
        description = "Modo servidor: containers, banco de dados, reverse proxy, backups";
        risk = "medium";
        affects = [
          "network"
          "storage"
          "security"
        ];
      })

      (mkFeature {
        id = "server.containers";
        label = "Server Containers";
        category = "server";
        description = "Runtime de containers para servidor (Podman)";
        risk = "low";
        requires = [ "server" ];
        affects = [ "virtualization" ];
      })

      (mkFeature {
        id = "server.database";
        label = "Server Database";
        category = "server";
        description = "Serviços de banco de dados (PostgreSQL, MariaDB)";
        risk = "medium";
        requires = [ "server" ];
        affects = [ "storage" ];
      })

      (mkFeature {
        id = "server.reverseProxy";
        label = "Reverse Proxy";
        category = "server";
        description = "Proxy reverso (Nginx, Traefik)";
        risk = "medium";
        requires = [ "server" ];
        affects = [
          "network"
          "security"
        ];
      })

      # =====================================================================
      # Additional features (existing modules/nixos/features/)
      # =====================================================================
      (mkFeature {
        id = "security.firewall";
        label = "Strict Firewall (legacy)";
        category = "security";
        description = "Firewall estrito permitindo apenas serviços explícitos";
        risk = "high";
        experimental = true;
        affects = [
          "network"
          "security"
        ];
      })

      (mkFeature {
        id = "security.fail2ban";
        label = "Fail2Ban";
        category = "security";
        description = "Prevenção de intrusão Fail2Ban (SSH brute force)";
        risk = "low";
        requires = [ "remote.ssh" ];
        affects = [
          "security"
          "ssh"
        ];
      })

      (mkFeature {
        id = "observability.prometheus";
        label = "Prometheus";
        category = "observability";
        description = "Coleta de métricas Prometheus";
        risk = "low";
        experimental = true;
        affects = [ ];
      })

      (mkFeature {
        id = "observability.grafana";
        label = "Grafana";
        category = "observability";
        description = "Dashboards Grafana";
        risk = "low";
        requires = [ "observability.prometheus" ];
        experimental = true;
        affects = [ ];
      })

      (mkFeature {
        id = "storage.srvData";
        label = "Dedicated /srv/data";
        category = "storage";
        description = "Mount dedicado para /srv/data (dados persistentes)";
        risk = "high";
        requiresReboot = true;
        affects = [ "storage" ];
      })

      (mkFeature {
        id = "storage.aiModels";
        label = "AI Model Cache";
        category = "storage";
        description = "Pré-cache de modelos de IA em /srv/data";
        risk = "low";
        requires = [
          "ai.ollama"
          "storage.srvData"
        ];
        affects = [ "storage" ];
      })

      (mkFeature {
        id = "mcp.filesystem";
        label = "MCP Filesystem";
        category = "mcp";
        description = "Integração MCP com sistema de arquivos";
        risk = "low";
        experimental = true;
        affects = [ ];
      })

      (mkFeature {
        id = "mcp.github";
        label = "MCP GitHub";
        category = "mcp";
        description = "Integração MCP com GitHub";
        risk = "low";
        experimental = true;
        affects = [ ];
      })

      (mkFeature {
        id = "mcp.neo4j";
        label = "MCP Neo4j";
        category = "mcp";
        description = "Integração MCP com Neo4j";
        risk = "low";
        requires = [ "ai.neo4j" ];
        experimental = true;
        affects = [ ];
      })

      (mkFeature {
        id = "mcp.ollama";
        label = "MCP Ollama";
        category = "mcp";
        description = "Integração MCP com Ollama";
        risk = "low";
        requires = [ "ai.ollama" ];
        experimental = true;
        affects = [ ];
      })

      (mkFeature {
        id = "browserAutomation";
        label = "Browser Automation";
        category = "development";
        description = "Automação de navegador (Playwright, browsers)";
        risk = "low";
        experimental = true;
        affects = [ ];
      })
    ];
  };
}
