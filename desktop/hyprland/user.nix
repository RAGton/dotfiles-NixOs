# =============================================================================
# user.nix — Orquestrador Hyprland (Home Manager)
#
# Puro roteador de imports. Toda config vive nos módulos abaixo.
# =============================================================================
{ nhModules, ... }:
{
  imports = [
    # Externos (nix-helper)
    "${nhModules}/misc/gtk"
    "${nhModules}/misc/qt"
    "${nhModules}/misc/wallpaper"
    "${nhModules}/misc/xdg"
    "${nhModules}/programs/swappy"

    # Wrappers e monitors existentes
    ./monitors.nix
    ./wrappers.nix
    ./theme

    # Bloco 1: configuração Hyprland extraída do hyprland.conf
    ./core/monitors.nix
    ./core/rules.nix
    ./core/keybinds.nix

    # Bloco 2: config user-level extraída de user.nix
    ./core/hyprland.nix
    ./core/packages.nix
    ./core/xdg.nix
    ./core/mime.nix
    ./core/dconf.nix
    ./core/cursor.nix
    ./caelestia/hyprpaper.nix
  ];
}
