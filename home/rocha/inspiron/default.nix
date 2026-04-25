{ lib, pkgs, ... }:
{
  imports = [
    ../../../modules/home-manager/common
    ../../../desktop/hyprland/shell-backend.nix
    ../../../desktop/hyprland/user.nix
    ../../../desktop/hyprland/rice/caelestia-config.nix
    ./caelestia-shell.nix
    ../../shared/dev-workstation.nix
    ../shared/vscode.nix
  ];

  kryonix.shell.backend = "caelestia";
  kryonix.programs.aiWorkstation.enable = true;

  home.packages = with pkgs; [
    atlauncher
  ];

  # No inspiron, o usuário quer a sessão sempre ativa: sem dim, sem DPMS off
  # e sem suspensão disparada pelo hypridle.
  xdg.configFile."hypr/hypridle.conf" = lib.mkForce {
    force = true;
    text = ''
      general {
        after_sleep_cmd = hyprctl dispatch dpms on
        ignore_dbus_inhibit = false
      }
    '';
  };

  wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
    general {
      gaps_in = 3
      gaps_out = 6
      border_size = 2
    }

    decoration {
      rounding = 8
      active_opacity = 1.0
      inactive_opacity = 1.0

      blur {
        enabled = false
      }
    }

    animations {
      enabled = true
      animation = windows, 1, 3, default
      animation = fade, 1, 3, default
      animation = border, 0
      animation = workspaces, 0
      animation = layers, 0
    }

    misc {
      vfr = true
    }
  '';

}
