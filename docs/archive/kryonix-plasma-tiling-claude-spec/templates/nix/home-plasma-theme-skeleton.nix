# Skeleton: Home Manager Plasma theme config
{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.kryonix.home.desktop.plasma.theme;
in
{
  options.kryonix.home.desktop.plasma.theme = {
    enable = lib.mkEnableOption "Kryonix Dark Plasma theme";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      inter
      papirus-icon-theme
      bibata-cursors
    ];

    xdg.configFile."kdeglobals".text = ''
      [General]
      ColorScheme=KryonixDark
      Name=Kryonix Dark

      [KDE]
      SingleClick=false

      [Icons]
      Theme=Papirus-Dark

      [Mouse]
      cursorTheme=Bibata-Modern-Ice
    '';
  };
}
