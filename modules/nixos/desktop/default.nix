{ config, lib, ... }:
let
  env = config.kryonix.desktop.environment;
in
{
  imports = [
    ./caelestia
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
  ];
}
