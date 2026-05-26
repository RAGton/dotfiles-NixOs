{ lib, pkgs, ... }:
let
  runIfOnBattery = pkgs.writeShellScript "kryonix-run-if-on-battery" ''
    set -euo pipefail

    found_ac=0
    ac_online=0

    for f in /sys/class/power_supply/*/online; do
      case "$f" in
        */AC*/online|*/ACAD*/online|*/ADP*/online|*/Mains*/online)
          found_ac=1
          if [ "$(cat "$f" 2>/dev/null || echo 0)" = "1" ]; then
            ac_online=1
            break
          fi
          ;;
      esac
    done

    # Sem telemetria AC, assume tomada para evitar suspensao indevida.
    if [ "$found_ac" -eq 0 ]; then
      ac_online=1
    fi

    if [ "$ac_online" -eq 0 ]; then
      exec "$@"
    fi
  '';
in
{
  imports = [
    ../../../modules/home-manager/common
    ../../../modules/home-manager/programs/obsidian
    ../../../desktop/hyprland/shell-backend.nix
    ../../../desktop/hyprland/user.nix
    ../../../desktop/hyprland/rice/caelestia-config.nix
    ./caelestia-shell.nix
    ../shared/vscode.nix
  ];

  kryonix.shell.backend = "caelestia";
  kryonix.programs.aiWorkstation.enable = true;
  services.kryonix-brain-tunnel.enable = true;
  services.kryonix-glacier-vnc-tunnel.enable = true;
  services.kryonix-ollama-tunnel.enable = true;

  programs.jupyter = {
    enable = true;
    kernels = {
      python = true;
      c = true;
      rust = true;
      cpp = true;
      bash = true;
      dotnet = false;
      node = false;
    };
  };

  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    atlauncher
    remmina
  ];

  # No AC, a sessao fica ativa. Em bateria, idle e suspend sao controlados
  # por timeouts conservadores; hibernate continua bloqueado no NixOS.
  xdg.configFile."hypr/hypridle.conf" = lib.mkForce {
    force = true;
    text = ''
      general {
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = hyprctl dispatch dpms on
        ignore_dbus_inhibit = false
      }

      # Bateria, 10 min: reduzir brilho sem apagar tela.
      listener {
        timeout = 600
        on-timeout = ${runIfOnBattery} brightnessctl -s set 35%
        on-resume  = brightnessctl -r
      }

      # Bateria, 20 min: apagar display.
      listener {
        timeout = 1200
        on-timeout = ${runIfOnBattery} hyprctl dispatch dpms off
        on-resume  = hyprctl dispatch dpms on
      }

      # Bateria, 45 min: suspender. Em AC, o helper nao executa nada.
      listener {
        timeout = 2700
        on-timeout = ${runIfOnBattery} systemctl suspend
      }
    '';
  };

  wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
    general {
      gaps_in = 3
      gaps_out = 6
      border_size = 5
    }

    decoration {
      rounding = 8
      active_opacity = 0.9
      inactive_opacity = 0.8

      blur {
        enabled = false
      }
    }

    animations {
      enabled = true
    }

  '';

}
