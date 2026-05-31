# Host: iso (Live CD / instalador automatizado)
#
# Objetivo
# - Gerar uma ISO bootável que facilite a instalação dos hosts deste flake.
# - A ISO traz um script `kryonix-install` que particiona (Disko) e roda `nixos-install`.
{
  inputs,
  hostname,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    # Base do instalador do NixOS (ISO minimal)
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")

    # Nosso módulo de instalador automatizado
    ../../modules/nixos/installer
    ../../modules/nixos/installer/web-kiosk.nix
    ../../modules/shared/nixpkgs

    # Branding Kryonix (GRUB tema + Plymouth + os-release)
    ../../modules/nixos/branding/kryonix/default.nix
  ];

  networking.hostName = lib.mkForce "kryonix";
  kryonix.installer.kiosk.enable = true;
  kryonix.branding.enable = true;

  # ── Rede: ethernet DHCP automático + WiFi via NetworkManager ──────────────
  # O instalador precisa de internet antes do passo 1 (OAuth GitHub).
  # nmcli é a ponte entre o backend Axum e as interfaces de rede.
  networking.networkmanager.enable = lib.mkForce true;
  # Desabilita dhcpcd para evitar conflito com NM
  networking.useDHCP = lib.mkForce false;

  # Firmware WiFi para as chips mais comuns (Intel, Realtek, Broadcom, Atheros)
  hardware.enableAllFirmware = lib.mkDefault true;
  hardware.enableRedistributableFirmware = lib.mkDefault true;

  # Usuário live precisa estar no grupo networkmanager para rodar nmcli sem sudo
  users.users.nixos.extraGroups = lib.mkDefault [ "networkmanager" "wheel" ];

  # ISO identity
  system.nixos.distroName    = lib.mkForce "Kryonix";
  system.nixos.label         = lib.mkForce "Kryonix-Installer";
  isoImage.isoBaseName       = lib.mkForce "kryonix";
  isoImage.volumeID          = lib.mkForce "KRYONIX";
  isoImage.appendToMenuLabel = lib.mkForce "Installer";

  # Plymouth: cd-minimal desabilita com mkForce, precisamos sobrescrever
  boot.plymouth.enable = lib.mkForce true;

  # Boot silencioso para Plymouth aparecer corretamente
  boot.initrd.verbose = lib.mkForce false;
  boot.consoleLogLevel = lib.mkForce 0;
  boot.kernelParams = lib.mkForce [
    "quiet"
    "splash"
    "loglevel=0"
    "systemd.show_status=false"
    "rd.systemd.show_status=false"
    "rd.udev.log_level=3"
  ];

  # ISO deve ser estável e pequena: evita trazer desktop completo.
  documentation.enable = lib.mkDefault false;

  # Ajuda no debug e instalação
  environment.systemPackages = with pkgs; [
    kryonix
    kryonix-hardware-probe
    git
    curl
    jq
    fzf
    # nmcli já vem pelo networkmanager; garantimos explicitamente para o backend
    networkmanager
    # iw é útil para debug manual de WiFi no terminal
    iw
  ];

  # Normalmente útil em instalação remota (opcional)
  services.openssh.enable = lib.mkDefault true;

  # Evita pedir senha no live. Chave pode ser adicionada depois.
  users.users.nixos.openssh.authorizedKeys.keys = lib.mkDefault [ ];
}
