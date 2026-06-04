# ==============================================================================
# Módulo: Host Inspiron
# Autor: rag
#
# O que é:
# - Configuração NixOS específica do host `inspiron`.
# - Workstation principal com Hyprland e ambiente de desenvolvimento.
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

    # Disko
    inputs.disko.nixosModules.disko
    ./disks.nix

    # Módulos compartilhados
    ../../hosts/common
  ];

  # =========================
  # Kryonix Options (Declarativo)
  # =========================

  # Desktop
  kryonix.desktop.environment = "hyprland";
  kryonix.shell.caelestia.enable = true;

  # Ativação via Perfis (Modular)
  kryonix.profiles = {
    laptop.enable = true;

    dev = {
      enable = true;
      enableRust = true;
      enableCpp = true;
      enableJupyter = true; # Reativa o ambiente Python/Jupyter
    };

    virtualization = {
      enable = true;
      libvirt = true; # Reativa o Libvirt
    };

    tools = {
      vscodeInsiders = true; # Reativa o VSCode Insiders
    };

    university.enable = true;
    ti.enable = true;
  };

  # Features e ajustes finos
  kryonix.features.remoteDesktop.client.enable = true;
  kryonix.features.ai.brain = {
    enable = true;
    role = "client";
    serverHost = "rve-glacier"; # GLACIER (Tailscale Hostname)
  };

  networking.hostName = hostname;
  programs.winbox.enable = true;
  system.stateVersion = "26.05";

  # =========================
  # Boot / Kernel
  # =========================
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";
  };

  # Kernel Zen
  kernelZen = {
    enable = true;
    kernel = "zen";
  };

  # iGPU Intel
  services.xserver.videoDrivers = [ "modesetting" ];
  hardware.graphics.enable = true;

  # =========================
  # Tailscale
  # =========================
  services.kryonix.tailscale.enable = true;
}
