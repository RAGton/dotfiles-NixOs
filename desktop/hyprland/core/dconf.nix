# =============================================================================
# core/dconf.nix — Configurações dconf (Blueman, GNOME utils, GTK)
# =============================================================================
{ lib, config, ... }:
{
  config = lib.mkIf (config.wayland.windowManager.hyprland.enable or false) {
    dconf.settings = {
      "org/blueman/general" = {
        "plugin-list" = lib.mkForce [ "!StatusNotifierItem" ];
      };

      "org/blueman/plugins/powermanager" = {
        "auto-power-on" = true;
      };

      "org/gnome/calculator" = {
        "accuracy" = 9;
        "angle-units" = "degrees";
        "base" = 10;
        "button-mode" = "basic";
        "number-format" = "automatic";
        "show-thousands" = false;
        "show-zeroes" = false;
        "source-currency" = "";
        "source-units" = "degree";
        "target-currency" = "";
        "target-units" = "radian";
        "window-maximized" = false;
      };

      "org/gnome/desktop/wm/preferences" = {
        "button-layout" = lib.mkForce "";
      };

      "org/gnome/nm-applet" = {
        "disable-connected-notifications" = true;
        "disable-vpn-notifications" = true;
      };

      "org/gtk/gtk4/settings/file-chooser" = {
        "show-hidden" = true;
      };

      "org/gtk/settings/file-chooser" = {
        "date-format" = "regular";
        "location-mode" = "path-bar";
        "show-hidden" = true;
        "show-size-column" = true;
        "show-type-column" = true;
        "sort-column" = "name";
        "sort-directories-first" = false;
        "sort-order" = "ascending";
        "type-format" = "category";
        "view-type" = "list";
      };
    };
  };
}
