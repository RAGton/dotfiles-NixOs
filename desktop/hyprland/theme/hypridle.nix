{ pkgs, ... }:
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
  services.hypridle = {
    enable = true;

    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
        ignore_dbus_inhibit = false;
      };

      listener = [
        {
          # Dim após 4 min
          timeout = 240;
          on-timeout = "brightnessctl -s set 30%";
          on-resume = "brightnessctl -r";
        }
        {
          # Bloquear após 6 min
          timeout = 360;
          on-timeout = "loginctl lock-session";
        }
        {
          # Bateria, 10 min: apagar display
          timeout = 600;
          on-timeout = "${runIfOnBattery} hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          # Bateria, 45 min: suspender
          timeout = 2700;
          on-timeout = "${runIfOnBattery} systemctl suspend";
        }
      ];
    };
  };
}
