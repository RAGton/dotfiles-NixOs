# =============================================================================
# Host: Glacier
#
# O que é:
# - Composição declarativa do host Glacier.
# - Toda lógica está nos perfis glacier-base/ai/gamer + rve-compat.nix.
# - Este arquivo contém apenas: imports, enables, kernel, boot e stateVersion.
#
# Perfis ativos:
# - glacier-base: NVIDIA, SSH, Tailscale, firewall, branding
# - glacier-ai:   Ollama + Brain + LightRAG (sem autostart, keep_alive=0)
# - glacier-gamer: Steam, Lutris, Wine, Heroic, OpenRGB, desktop
# - dev:          git, gh, lazygit, tmux, podman, neovim
# - ti:           nmap, tcpdump, wireshark, virt-manager, qemu
# =============================================================================
{
  inputs,
  hostname,
  lib,
  config,
  ...
}:
{
  imports = [
    # Hardware AMD + NVIDIA (nixos-hardware)
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-cpu-amd-pstate
    inputs.hardware.nixosModules.common-gpu-nvidia

    # ATENÇÃO: disks.nix e ragenterprise-disko.nix são apenas para referência de provisionamento.
    # Não importar aqui para layouts de instalação manual Btrfs real.
    ./hardware-configuration.nix
    ./rve-compat.nix
    ./bluetooth.nix
    ./storage.nix

    # Kernel e rede
    ../../modules/kernel/zen.nix
    ../../modules/virtualization/net-ragthink.nix
  ];

  # =========================
  # PROFILES — toda a lógica vive aqui
  # =========================
  kryonix.profiles.glacier-base.enable = true;
  kryonix.profiles.glacier-ai.enable = true;
  kryonix.profiles.glacier-gamer.enable = true;

  # Perfis funcionais
  kryonix.profiles.dev.enable = true;
  kryonix.profiles.ti.enable = true;
  kryonix.features.remoteDesktop.server.enable = true;

  # =========================
  # EXPERIMENTAL — llama.cpp CUDA Sidecar (A/B Benchmark)
  # Issue: #48 — Backend experimental llama.cpp/provider auto/fallback
  # =========================
  kryonix.services.llama-cpp = {
    enable = false;
    modelPath = "/var/lib/kryonix/models/Qwen2.5-7B-Instruct-Q4_K_M.gguf";
    gpuLayers = -1; # Todas na GPU RTX 4060
    ctxSize = 16384; # Aumentado de 8k para 16k para suportar RAG denso
    extraArgs = [
      "--flash-attn"
      "on"
    ]; # Melhor performance e menor uso de VRAM
  };

  # Configuração do Brain para usar o backend experimental com fallback automático
  kryonix.services.brain.llmProvider = "auto";

  # KORA — Assistente pessoal local (gateway/orchestrator)
  kryonix.services.kora = {
    enable = true;
    # Bind em 0.0.0.0 é seguro aqui porque o firewall do módulo (kryonix.services.kora)
    # restringe explicitamente o acesso às interfaces tailscale0 e br0.
    host = "0.0.0.0";
    port = 8787;
    memory.enable = true;
    voice = {
      enable = true;
      alwaysOn = true;
    };
  };

  # =========================
  # N8N — Motor de automação visual (gateway/orchestrator)
  # =========================
  kryonix.services.n8n = {
    enable = true;
  };

  # =========================
  # Home Assistant — Automação residencial
  # =========================
  kryonix.services.home-assistant = {
    enable = true;
  };

  # =========================
  # TAILSCALE (RVE-specific, não genérico)
  # =========================
  # authKeyFile e extraUpFlags são identidade deste host — ficam aqui.
  services.kryonix.tailscale = {
    autoconnect = true;
    advertiseExitNode = true;
    authKeyFile = /root/tailscale-authkey.secret;
    extraUpFlags = [ "--hostname=RVE-GLACIER" ];
  };

  # KERNEL ZEN (hardware-specific)
  # =========================
  kernelZen = {
    enable = true;
    kernel = "zen";
    forceLocalBuild = lib.mkDefault false;
    useLLVMStdenv = lib.mkDefault false;
    extraMakeFlags = [ ];
    disableMitigations = lib.mkDefault false;
    extraKernelParams = [ ];
  };

  # =========================
  # NETWORK — hostname apenas (IP, bridge, firewall em rve-compat e glacier-base)
  # =========================
  networking.hostName = hostname;

  # =========================
  # BOOT (hardware-specific)
  # =========================
  boot = {
    supportedFilesystems = [ "btrfs" ];
    loader = {
      systemd-boot.enable = lib.mkForce false;
      grub = {
        enable = lib.mkForce true;
        efiSupport = true;
        device = "nodev";
        useOSProber = false;
        # Instala também no local removível/fallback (/EFI/BOOT/BOOTX64.EFI)
        # Útil para firmwares UEFI que perdem entradas ou priorizam o fallback.
        efiInstallAsRemovable = true;
      };
      efi = {
        canTouchEfiVariables = lib.mkForce false;
        efiSysMountPoint = "/boot";
      };
    };

    initrd.systemd.enable = true;
  };

  # =========================
  # SYSTEM
  # =========================
  users.users.rocha.extraGroups = [
    "bluetooth"
    "lp"
  ];

  system.stateVersion = "26.05";
}
