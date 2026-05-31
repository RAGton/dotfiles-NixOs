# =============================================================================
# core/cursor.nix — Cursor consistente em GTK, X11 e Wayland
#
# Herda o nome e pacote do cursorTheme definido em theme/gtk.nix.
# =============================================================================
{ lib, config, ... }:
{
  config = lib.mkIf (config.wayland.windowManager.hyprland.enable or false) {
    home.pointerCursor = {
      gtk.enable = true;
      x11.enable = true;
      package = config.gtk.cursorTheme.package;
      name = config.gtk.cursorTheme.name;
      size = 24;
    };
  };
}
