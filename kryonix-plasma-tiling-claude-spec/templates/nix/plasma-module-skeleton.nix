# Skeleton: NixOS Plasma opt-in module
# Ajuste para o namespace real do Kryonix antes de usar.
{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.kryonix.desktop.plasma;
in
{
  options.kryonix.desktop.plasma = {
    enable = lib.mkEnableOption "KDE Plasma desktop profile for Kryonix";
    setDefaultSession = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to make Plasma the default display manager session.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.desktopManager.plasma6.enable = true;

    # Escolha conforme nixpkgs/release real:
    # services.displayManager.plasma-login-manager.enable = true;
    services.displayManager.sddm.enable = lib.mkDefault true;
    services.displayManager.sddm.wayland.enable = lib.mkDefault true;

    services.displayManager.defaultSession = lib.mkIf cfg.setDefaultSession (lib.mkDefault "plasma");
  };
}
