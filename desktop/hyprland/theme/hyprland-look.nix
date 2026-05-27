{ lib, ... }:
let
  p = import ./palette.nix;
in
{
  wayland.windowManager.hyprland.settings = {
    general = {
      border_size = 1;
      "col.active_border" = "rgb(${p.hud1}) rgb(${p.hud3}) 45deg";
      "col.inactive_border" = "rgb(${p.border})";
      gaps_in = 4;
      gaps_out = 8;
      layout = "master";
    };

    decoration = {
      rounding = 6;

      # Blur sutil — HUD tem leveza, não é pesado
      blur = {
        enabled = true;
        size = 4;
        passes = 2;
        noise = 0.02;
        contrast = 0.9;
        xray = false;
      };

      shadow = {
        enabled = true;
        range = 12;
        render_power = 2;
        color = "rgba(00d4ff18)"; # sombra ciano
      };
    };

    animations = {
      enabled = true;

      # Bezier curvas suaves — fluido mas rápido
      bezier = [
        "snap,   0.19, 1.0, 0.22, 1.0" # abertura rápida
        "glide,  0.4,  0.0, 0.2, 1.0" # movimento suave
        "fade,   0.0,  0.0, 0.2, 1.0" # fade limpo
      ];

      animation = [
        "windows,       1, 3,  snap,  popin 85%"
        "windowsOut,    1, 2,  fade,  popin 85%"
        "windowsMove,   1, 3,  glide"
        "border,        1, 8,  glide"
        "borderangle,   1, 12, glide"
        "fade,          1, 4,  fade"
        "workspaces,    1, 3,  glide, slidevert"
        "specialWorkspace, 1, 4, glide, slidefadevert 20%"
      ];
    };

    misc = {
      force_default_wallpaper = 0;
      disable_hyprland_logo = true;
      disable_splash_rendering = true;
      vfr = true;
      disable_autoreload = true;
    };

    render = {
      explicit_sync = 2;
    };

    cursor = {
      no_hardware_cursors = false;
    };
  };
}
