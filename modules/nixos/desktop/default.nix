{ config, lib, ... }:
let
  env = config.kryonix.desktop.environment;
in
{
  imports = [
    ./caelestia
    ./kde
    ../../../desktop/hyprland/system.nix
  ];

  config = lib.mkMerge [
    (lib.mkIf (env == "hyprland") {
      kryonix.desktop.directLogin.enable = lib.mkForce false;

      services.displayManager.gdm.enable = lib.mkForce false;
      services.displayManager.sddm.enable = lib.mkForce true;
      services.desktopManager.plasma6.enable = lib.mkForce false;
      services.desktopManager.gnome.enable = lib.mkForce false;
      services.greetd.enable = lib.mkForce false;

      programs.dconf.enable = true;
      programs.hyprlock.enable = lib.mkDefault true;
    })

    # KDE Plasma 6 — ambiente principal de longo prazo.
    # Os enables positivos (sddm wayland, plasma6) vivem em ./kde/default.nix
    # (espelhando o padrão do system.nix do Hyprland). Aqui só garantimos a
    # exclusão de display/desktop managers conflitantes.
    (lib.mkIf (env == "kde") {
      kryonix.desktop.directLogin.enable = lib.mkForce false;

      # Caelestia é específico do Hyprland (assertion exige env=="hyprland").
      # Perfis workstation habilitam caelestia por mkDefault — forçamos off no KDE.
      kryonix.shell.caelestia.enable = lib.mkForce false;

      services.displayManager.gdm.enable = lib.mkForce false;
      services.desktopManager.gnome.enable = lib.mkForce false;
      services.greetd.enable = lib.mkForce false;
    })
  ];
}
