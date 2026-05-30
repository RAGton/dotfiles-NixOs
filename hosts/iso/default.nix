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

  # ISO identity
  system.nixos.distroName    = lib.mkForce "Kryonix";
  system.nixos.label         = lib.mkForce "Kryonix-Installer";
  isoImage.isoBaseName       = lib.mkForce "kryonix";
  isoImage.volumeID          = lib.mkForce "KRYONIX";
  # appendToMenuLabel controls the GRUB entry: "<distroName> <appendToMenuLabel>"
  # Without override: "Kryonix Kryonix-Installer Installer" (distroName + label + "Installer")
  isoImage.appendToMenuLabel = lib.mkForce "Installer";
  # Remove NixOS blue splash — our grubTheme's background.png replaces it
  isoImage.splashImage    = lib.mkForce null;
  isoImage.efiSplashImage = lib.mkForce null;

  # Plymouth: cd-minimal desabilita com mkForce, precisamos sobrescrever
  boot.plymouth.enable = lib.mkForce true;

  # Boot silencioso para Plymouth aparecer corretamente
  boot.initrd.verbose = lib.mkForce false;
  boot.consoleLogLevel = lib.mkForce 0;
  boot.kernelParams = lib.mkAfter [
    "quiet"
    "splash"
    "loglevel=0"
    "systemd.show_status=false"
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
  ];

  # Normalmente útil em instalação remota (opcional)
  services.openssh.enable = lib.mkDefault true;

  # Evita pedir senha no live. Chave pode ser adicionada depois.
  users.users.nixos.openssh.authorizedKeys.keys = lib.mkDefault [ ];
}
