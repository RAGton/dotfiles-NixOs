# ==============================================================================
# Módulo: Hyprland (User-level)
# Autor: Gabriel Rocha (rag) + Codex
# Data: 2026-03-12
#
# O que é:
# - Configuração Home Manager do Hyprland (arquivos em ~/.config/hypr e serviços user).
# - Mantém apenas a camada user-level declarativa do desktop e do shell ativo.
#
# Por quê:
# - Evita duplicação entre shell, Waybar, Wofi e outros daemons de sessão.
# - Garante idle/lock declarativos com integração correta ao logind.
#
# Como:
# - Publica `hyprland.conf`, `hypridle.conf` e `hyprlock.conf`.
# - Mantém o launcher principal no Caelestia, sem impedir launchers auxiliares.
#
# Riscos:
# - Ajustes agressivos de idle/lock podem interromper workflows longos se mal calibrados.
# ==============================================================================
{
  config,
  lib,
  pkgs,
  nhModules,
  ...
}:
let
  configuredShellBackend = config.kryonix.shell.backend or null;
  shellBackend = configuredShellBackend;
  shellProvidesChrome = shellBackend != null;
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

    # Se não houver telemetria AC disponível, assume conectado para evitar
    # suspender/desligar tela indevidamente em desktops.
    if [ "$found_ac" -eq 0 ]; then
      ac_online=1
    fi

    if [ "$ac_online" -eq 0 ]; then
      exec "$@"
    fi
  '';
  kryonixMenu = pkgs.writeShellApplication {
    name = "kryonix-menu";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      fuzzel
      fzf
      gawk
    ];
    text = ''
      set -euo pipefail

      prompt="> "
      delimiter=""
      with_nth=""
      accept_nth=""
      only_match=0
      query_mode=0

      while [ "$#" -gt 0 ]; do
        case "$1" in
          --prompt)
            shift
            [ "$#" -gt 0 ] || exit 2
            prompt="$1"
            ;;
          --prompt=*)
            prompt="''${1#--prompt=}"
            ;;
          --delimiter)
            shift
            [ "$#" -gt 0 ] || exit 2
            delimiter="$1"
            ;;
          --delimiter=*)
            delimiter="''${1#--delimiter=}"
            ;;
          --with-nth)
            shift
            [ "$#" -gt 0 ] || exit 2
            with_nth="$1"
            ;;
          --with-nth=*)
            with_nth="''${1#--with-nth=}"
            ;;
          --accept-nth)
            shift
            [ "$#" -gt 0 ] || exit 2
            accept_nth="$1"
            ;;
          --accept-nth=*)
            accept_nth="''${1#--accept-nth=}"
            ;;
          --only-match)
            only_match=1
            ;;
          --query)
            query_mode=1
            ;;
          *)
            echo "kryonix-menu: argumento desconhecido: $1" >&2
            exit 2
            ;;
        esac
        shift
      done

      tmp="$(mktemp)"
      cleanup() { rm -f "$tmp"; }
      trap cleanup EXIT
      cat > "$tmp"

      choose_fuzzel() {
        local -a args

        args=(
          --dmenu
          "--prompt=$prompt"
          --lines=12
          --width=72
          --layer=overlay
          --match-mode=fzf
          --minimal-lines
          --no-icons
        )

        if [ -n "$delimiter" ]; then
          args+=("--nth-delimiter=$delimiter")
        fi
        if [ -n "$with_nth" ]; then
          args+=("--with-nth=$with_nth")
        fi
        if [ -n "$accept_nth" ]; then
          args+=("--accept-nth=$accept_nth")
        fi
        if [ "$only_match" -eq 1 ] && [ "$query_mode" -eq 0 ]; then
          args+=(--only-match)
        fi

        fuzzel "''${args[@]}" < "$tmp"
      }

      choose_fzf() {
        local selection
        local fzf_delimiter
        local -a args
        args=(
          "--prompt=$prompt"
          --layout=reverse
          --height=100%
          --border
        )

        if [ -n "$delimiter" ] && [ -n "$with_nth" ]; then
          fzf_delimiter="$delimiter"
          case "$fzf_delimiter" in
            "|")
              fzf_delimiter="[|]"
              ;;
          esac
          args+=("--delimiter=$fzf_delimiter" "--with-nth=$with_nth")
        fi
        if [ "$query_mode" -eq 1 ]; then
          args+=(--print-query --phony)
          selection="$(fzf "''${args[@]}" < "$tmp" | head -n1)" || return 1
        else
          selection="$(fzf "''${args[@]}" < "$tmp")" || return 1
        fi

        if [ -n "$accept_nth" ]; then
          if [ -n "$delimiter" ] && [ "''${#delimiter}" -eq 1 ]; then
            printf '%s\n' "$selection" | cut -d "$delimiter" -f "$accept_nth"
          else
            printf '%s\n' "$selection"
          fi
        else
          printf '%s\n' "$selection"
        fi
      }

      if [ -n "''${WAYLAND_DISPLAY-}" ] && command -v fuzzel >/dev/null 2>&1; then
        choose_fuzzel
      else
        choose_fzf
      fi
    '';
  };
in
{
  imports = [
    "${nhModules}/misc/gtk"
    "${nhModules}/misc/qt"
    "${nhModules}/misc/wallpaper"
    "${nhModules}/misc/xdg"
    "${nhModules}/programs/swappy"
  ];

  config = lib.mkMerge [
    {
      # Monitores: voltar ao padrão do shell/Hyprland (sem kanshi forçando scale/posições).
      services.kanshi.enable = lib.mkForce false;

      # Screenshot stack (Wayland nativo) no nível do usuário, para os binds funcionarem
      # mesmo antes de um `nixos-rebuild`.
      home.packages = with pkgs; [
        grim
        slurp
        wl-clipboard
        swappy
        libnotify
        jq
        hyprland
        hyprpicker
        wf-recorder
        libqalculate
        brightnessctl
        kdePackages.ark
        kryonixMenu

        (writeShellApplication {
          name = "grimblast";
          runtimeInputs = [
            bash
            coreutils
            grim
            slurp
            wl-clipboard
            libnotify
            jq
            hyprland
          ];
          text = ''
            set -euo pipefail

            notify=0
            if [[ "''${1-}" = "--notify" ]]; then
              notify=1
              shift
            fi

            verb="''${1-}"
            target="''${2-}"

            screenshots_dir="''${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
            mkdir -p "$screenshots_dir"
            ts="$(date +%F_%H-%M-%S)"
            file="$screenshots_dir/Screenshot_$ts.png"

            do_notify() {
              [[ "$notify" = 1 ]] || return 0
              notify-send -a "screenshot" "$@" >/dev/null 2>&1 || true
            }

            usage() {
              echo "Uso: grimblast [--notify] <copy|save|copysave> <area|screen|active>" >&2
              exit 2
            }

            [[ -n "$verb" && -n "$target" ]] || usage

            case "$target" in
              area)
                geometry="$(slurp)" || exit 0
                [[ -n "$geometry" ]] || exit 0
                case "$verb" in
                  copy)
                    grim -g "$geometry" - | wl-copy
                    do_notify "Screenshot" "Área copiada para o clipboard"
                    ;;
                  save)
                    grim -g "$geometry" "$file"
                    do_notify "Screenshot" "Área salva: $(basename "$file")"
                    ;;
                  copysave)
                    grim -g "$geometry" "$file"
                    wl-copy < "$file"
                    do_notify "Screenshot" "Área salva e copiada: $(basename "$file")"
                    ;;
                  *) usage ;;
                esac
                ;;

              screen)
                case "$verb" in
                  copy)
                    grim - | wl-copy
                    do_notify "Screenshot" "Tela copiada para o clipboard"
                    ;;
                  save)
                    grim "$file"
                    do_notify "Screenshot" "Tela salva: $(basename "$file")"
                    ;;
                  copysave)
                    grim "$file"
                    wl-copy < "$file"
                    do_notify "Screenshot" "Tela salva e copiada: $(basename "$file")"
                    ;;
                  *) usage ;;
                esac
                ;;

              active)
                x="$(hyprctl -j activewindow | jq -r '.at[0] // empty')"
                y="$(hyprctl -j activewindow | jq -r '.at[1] // empty')"
                w="$(hyprctl -j activewindow | jq -r '.size[0] // empty')"
                h="$(hyprctl -j activewindow | jq -r '.size[1] // empty')"
                [[ -n "$x" && -n "$y" && -n "$w" && -n "$h" ]] || {
                  echo "grimblast: não foi possível obter geometria da janela ativa" >&2
                  exit 1
                }
                geometry="$x,$y ''${w}x''${h}"
                case "$verb" in
                  copy)
                    grim -g "$geometry" - | wl-copy
                    do_notify "Screenshot" "Janela ativa copiada para o clipboard"
                    ;;
                  save)
                    grim -g "$geometry" "$file"
                    do_notify "Screenshot" "Janela ativa salva: $(basename "$file")"
                    ;;
                  copysave)
                    grim -g "$geometry" "$file"
                    wl-copy < "$file"
                    do_notify "Screenshot" "Janela ativa salva e copiada: $(basename "$file")"
                    ;;
                  *) usage ;;
                esac
                ;;

              *) usage ;;
            esac
          '';
        })

        (writeShellApplication {
          name = "kryonix-screenshot";
          runtimeInputs = [
            bash
            coreutils
            grim
            slurp
            wl-clipboard
            swappy
            libnotify
            grimblast
          ];
          text = ''
            set -euo pipefail

            action="''${1-}"
            shift || true

            case "$action" in
              copy-area)
                exec grimblast --notify copy area
                ;;

              copysave-screen)
                exec grimblast --notify copysave screen
                ;;

              copysave-active)
                exec grimblast --notify copysave active
                ;;

              edit-area)
                tmp="''${TMPDIR:-/tmp}/screenshot-area-$(date +%F_%H-%M-%S).png"
                geometry="$(slurp)" || exit 0
                [[ -n "$geometry" ]] || exit 0
                grim -g "$geometry" "$tmp"
                exec swappy -f "$tmp"
                ;;

              edit-output)
                tmp="''${TMPDIR:-/tmp}/screenshot-screen-$(date +%F_%H-%M-%S).png"
                grim "$tmp"
                exec swappy -f "$tmp"
                ;;

              *)
                echo "Uso: kryonix-screenshot {copy-area|copysave-screen|copysave-active|edit-area|edit-output}" >&2
                exit 2
                ;;
            esac
          '';
        })

        (writeShellApplication {
          name = "kryonix-brightness";
          runtimeInputs = [
            bash
            brightnessctl
          ];
          text = ''
            set -euo pipefail

            case "''${1-}" in
              up)
                exec brightnessctl -q set 10%+
                ;;
              down)
                exec brightnessctl -q set 10%-
                ;;
              max)
                exec brightnessctl -q set 100%
                ;;
              min)
                exec brightnessctl -q set 1%
                ;;
              *)
                echo "Uso: kryonix-brightness {up|down|max|min}" >&2
                exit 2
                ;;
            esac
          '';
        })

        (writeShellApplication {
          name = "kryonix-kbd-brightness";
          runtimeInputs = [
            bash
            coreutils
            brightnessctl
          ];
          text = ''
            set -euo pipefail
            shopt -s nullglob

            devices=(/sys/class/leds/*kbd_backlight*)
            [ "''${#devices[@]}" -gt 0 ] || exit 0
            device="$(basename "''${devices[0]}")"

            case "''${1-}" in
              up)
                exec brightnessctl -q -d "$device" set +33%
                ;;
              down)
                exec brightnessctl -q -d "$device" set 33%-
                ;;
              *)
                echo "Uso: kryonix-kbd-brightness {up|down}" >&2
                exit 2
                ;;
            esac
          '';
        })

        (writeShellApplication {
          name = "kryonix-launcher";
          runtimeInputs = [
            bash
            coreutils
            findutils
            kryonixMenu
            gtk3
            libnotify
          ];
          text = ''
            set -euo pipefail
            collect_desktop_files() {
              local data_dir
              local -a dirs
              dirs=()

              if [ -n "''${XDG_DATA_HOME-}" ]; then
                dirs+=("$XDG_DATA_HOME/applications")
              else
                dirs+=("$HOME/.local/share/applications")
              fi

              if [ -n "''${XDG_DATA_DIRS-}" ]; then
                IFS=: read -r -a xdg_dirs <<< "$XDG_DATA_DIRS"
                for data_dir in "''${xdg_dirs[@]}"; do
                  dirs+=("$data_dir/applications")
                done
              fi

              dirs+=(
                "$HOME/.local/share/applications"
                "$HOME/.nix-profile/share/applications"
                "/etc/profiles/per-user/''${USER:-''${LOGNAME:-}}/share/applications"
                "/run/current-system/sw/share/applications"
                "$HOME/.local/share/flatpak/exports/share/applications"
                "/var/lib/flatpak/exports/share/applications"
                "/usr/share/applications"
              )

              for data_dir in "''${dirs[@]}"; do
                [ -d "$data_dir" ] || continue
                find "$data_dir" -type f -name "*.desktop" -printf '%f|%p\n' 2>/dev/null
              done | sort -u
            }

            app="$(collect_desktop_files | kryonix-menu --prompt 'Apps> ' --delimiter '|' --with-nth 1 --accept-nth 2 --only-match)" || exit 0
            [ -n "$app" ] || exit 0

            desktop_id="$(basename "$app")"
            gtk-launch "$desktop_id" "$@" || gtk-launch "''${desktop_id%.desktop}" "$@"
          '';
        })

        (writeShellApplication {
          name = "kryonix-clipboard-menu";
          runtimeInputs = [
            bash
            coreutils
            cliphist
            wl-clipboard
            kryonixMenu
            libnotify
          ];
          text = ''
            set -euo pipefail
            sel="$(cliphist list | kryonix-menu --prompt 'Clipboard> ' --only-match)" || exit 0
            [ -n "$sel" ] || exit 0
            cliphist decode <<<"$sel" | wl-copy
          '';
        })

        (writeShellApplication {
          name = "kryonix-ipc";
          runtimeInputs = [
            bash
            coreutils
            gawk
            jq
            procps
          ];
          text = ''
            set -euo pipefail

            pid="$(
              caelestia-shell list --all --json 2>/dev/null \
                | jq -r 'map(select(.config_path | contains("caelestia-shell/shell.qml"))) | first | .pid // empty' \
                || true
            )"

            if [ -z "$pid" ]; then
              pid="$(pidof caelestia-shell 2>/dev/null | awk '{print $1}' || true)"
            fi

            if [ -z "$pid" ]; then
              pid="$(pidof quickshell 2>/dev/null | awk '{print $1}' || true)"
            fi

            [ -n "$pid" ] || exit 1

            qs_bin="$(readlink -f "/proc/$pid/exe")"
            [ -n "$qs_bin" ] || exit 1

            exec "$qs_bin" ipc --pid "$pid" call "$@"
          '';
        })

        (writeShellApplication {
          name = "kryonix-shell-launcher";
          runtimeInputs = [
            bash
            coreutils
          ];
          text = ''
            set -euo pipefail

            exec kryonix-launcher "$@"
          '';
        })

        (writeShellApplication {
          name = "kryonix-shell-dashboard";
          runtimeInputs = [
            bash
            coreutils
          ];
          text = ''
            set -euo pipefail

            backend="${if shellBackend == null then "none" else shellBackend}"

            case "$backend" in
              caelestia)
                if command -v kryonix-ipc >/dev/null 2>&1 && kryonix-ipc drawers toggle dashboard; then
                  exit 0
                fi
                ;;
            esac

            exec kryonix-quick-actions
          '';
        })

        (writeShellApplication {
          name = "kryonix-shell-notifications";
          runtimeInputs = [
            bash
            coreutils
            swaynotificationcenter
          ];
          text = ''
            set -euo pipefail

            backend="${if shellBackend == null then "none" else shellBackend}"

            case "$backend" in
              caelestia)
                if command -v kryonix-ipc >/dev/null 2>&1 && kryonix-ipc drawers toggle sidebar; then
                  exit 0
                fi
                ;;
              *)
                if command -v swaync-client >/dev/null 2>&1; then
                  exec swaync-client -t -sw
                fi
                exit 0
                ;;
            esac
          '';
        })

        (writeShellApplication {
          name = "kryonix-shell-notifications-clear";
          runtimeInputs = [
            bash
            coreutils
            swaynotificationcenter
          ];
          text = ''
            set -euo pipefail

            backend="${if shellBackend == null then "none" else shellBackend}"

            case "$backend" in
              caelestia)
                if command -v kryonix-ipc >/dev/null 2>&1 && kryonix-ipc notifs clear; then
                  exit 0
                fi
                ;;
              *)
                if command -v swaync-client >/dev/null 2>&1; then
                  exec swaync-client -cp
                fi
                exit 0
                ;;
            esac
          '';
        })

        (writeShellApplication {
          name = "kryonix-shell-lock";
          runtimeInputs = [
            bash
            coreutils
            systemd
          ];
          text = ''
            set -euo pipefail

            backend="${if shellBackend == null then "none" else shellBackend}"

            case "$backend" in
              caelestia)
                if command -v kryonix-ipc >/dev/null 2>&1 && kryonix-ipc lock lock; then
                  exit 0
                fi
                ;;
            esac

            exec loginctl lock-session
          '';
        })

        (writeShellApplication {
          name = "kryonix-power-menu";
          runtimeInputs = [
            bash
            coreutils
            kryonixMenu
            wlogout
            systemd
            hyprland
            libnotify
          ];
          text = ''
            set -euo pipefail

            backend="${if shellBackend == null then "none" else shellBackend}"

            case "$backend" in
              caelestia)
                if command -v kryonix-ipc >/dev/null 2>&1 && kryonix-ipc drawers toggle session; then
                  exit 0
                fi
                ;;
            esac

            if command -v wlogout >/dev/null 2>&1; then
              exec wlogout -b 5
            fi
            choice="$(printf '%s\n' 'Lock' 'Logout' 'Suspend' 'Reboot' 'Poweroff' | kryonix-menu --prompt 'Power> ' --only-match)" || exit 0

            case "$choice" in
              "Lock")
                exec loginctl lock-session
                ;;
              "Logout")
                exec hyprctl dispatch exit
                ;;
              "Suspend")
                exec systemctl suspend
                ;;
              "Reboot")
                exec systemctl reboot
                ;;
              "Poweroff")
                exec systemctl poweroff
                ;;
              *)
                exit 0
                ;;
            esac
          '';
        })

        (writeShellApplication {
          name = "kryonix-audio-menu";
          runtimeInputs = [
            bash
            coreutils
            gnugrep
            gawk
            kryonixMenu
            wireplumber
            pavucontrol
            pamixer
            playerctl
            libnotify
          ];
          text = ''
            set -euo pipefail
            menu="$(printf '%s\n' \
              'Abrir pavucontrol' \
              'Saída padrão' \
              'Entrada padrão' \
              'Toggle mute' \
              'Toggle mic' \
              'Play/Pause' \
              'Faixa seguinte' \
              'Faixa anterior' \
              | kryonix-menu --prompt 'Áudio> ' --only-match)" || exit 0

            case "$menu" in
              "Abrir pavucontrol")
                exec pavucontrol
                ;;
              "Saída padrão")
                out="$(wpctl status | awk '/Sinks:/{f=1;next}/Sources:/{f=0}f && $1 ~ /^[0-9]+\./{gsub("\.","",$1); print $1":"substr($0,index($0,$2))}' | kryonix-menu --prompt 'Saída> ' --only-match)" || exit 0
                [ -n "$out" ] || exit 0
                wpctl set-default "''${out%%:*}"
                ;;
              "Entrada padrão")
                inn="$(wpctl status | awk '/Sources:/{f=1;next}/Filters:/{f=0}f && $1 ~ /^[0-9]+\./{gsub("\.","",$1); print $1":"substr($0,index($0,$2))}' | kryonix-menu --prompt 'Entrada> ' --only-match)" || exit 0
                [ -n "$inn" ] || exit 0
                wpctl set-default "''${inn%%:*}"
                ;;
              "Toggle mute")
                exec pamixer --toggle-mute
                ;;
              "Toggle mic")
                exec pamixer --default-source --toggle-mute
                ;;
              "Play/Pause")
                exec playerctl play-pause
                ;;
              "Faixa seguinte")
                exec playerctl next
                ;;
              "Faixa anterior")
                exec playerctl previous
                ;;
              *)
                exit 0
                ;;
            esac
          '';
        })

        (writeShellApplication {
          name = "kryonix-network-menu";
          runtimeInputs = [
            bash
            coreutils
            kryonixMenu
            networkmanagerapplet
            blueman
            bluez
            libnotify
          ];
          text = ''
            set -euo pipefail
            bt_state="$(bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2; exit}')"
            if [ "$bt_state" = "yes" ]; then
              bt_action="Bluetooth: desligar"
            else
              bt_action="Bluetooth: ligar"
            fi

            choice="$(printf '%s\n' \
              'Editor de conexões' \
              'Bluetooth manager' \
              "$bt_action" \
              | kryonix-menu --prompt 'Rede/Bluetooth> ' --only-match)" || exit 0

            case "$choice" in
              "Editor de conexões")
                exec nm-connection-editor
                ;;
              "Bluetooth manager")
                exec blueman-manager
                ;;
              "Bluetooth: ligar")
                exec bluetoothctl power on
                ;;
              "Bluetooth: desligar")
                exec bluetoothctl power off
                ;;
              *)
                exit 0
                ;;
            esac
          '';
        })

        (writeShellApplication {
          name = "kryonix-record-menu";
          runtimeInputs = [
            bash
            coreutils
            kryonixMenu
            jq
            hyprland
            slurp
            wf-recorder
            libnotify
            procps
          ];
          text = ''
            set -euo pipefail

            recordings_dir="''${XDG_VIDEOS_DIR:-$HOME/Videos}/Recordings"
            mkdir -p "$recordings_dir"
            if pgrep -x wf-recorder >/dev/null 2>&1; then
              choice="$(printf '%s\n' 'Parar gravação' 'Cancelar' | kryonix-menu --prompt 'Screen Recorder> ' --only-match)" || exit 0
              [ "$choice" = "Parar gravação" ] || exit 0
              pkill -INT -x wf-recorder || true
              notify-send -a "screen-recorder" "Gravação" "Gravação finalizada"
              exit 0
            fi

            mode="$(printf '%s\n' 'Área' 'Janela ativa' 'Monitor atual' | kryonix-menu --prompt 'Gravar> ' --only-match)" || exit 0
            [ -n "$mode" ] || exit 0

            file="$recordings_dir/Recording_$(date +%F_%H-%M-%S).mp4"

            case "$mode" in
              "Área")
                geometry="$(slurp)" || exit 0
                [ -n "$geometry" ] || exit 0
                wf-recorder -f "$file" -g "$geometry" >/dev/null 2>&1 &
                ;;
              "Janela ativa")
                x="$(hyprctl -j activewindow | jq -r '.at[0] // empty')"
                y="$(hyprctl -j activewindow | jq -r '.at[1] // empty')"
                w="$(hyprctl -j activewindow | jq -r '.size[0] // empty')"
                h="$(hyprctl -j activewindow | jq -r '.size[1] // empty')"
                [ -n "$x" ] && [ -n "$y" ] && [ -n "$w" ] && [ -n "$h" ] || exit 1
                wf-recorder -f "$file" -g "$x,$y ''${w}x''${h}" >/dev/null 2>&1 &
                ;;
              "Monitor atual")
                monitor="$(hyprctl -j monitors | jq -r '.[] | select(.focused == true).name // empty' | head -n1)"
                [ -n "$monitor" ] || exit 1
                wf-recorder -f "$file" -o "$monitor" >/dev/null 2>&1 &
                ;;
              *)
                exit 0
                ;;
            esac

            notify-send -a "screen-recorder" "Gravação iniciada" "$(basename "$file")"
          '';
        })

        (writeShellApplication {
          name = "kryonix-window-menu";
          runtimeInputs = [
            bash
            coreutils
            kryonixMenu
            jq
            hyprland
            libnotify
          ];
          text = ''
            set -euo pipefail
            selection="$(
              hyprctl -j clients \
                | jq -r '.[] | select(.mapped == true) | "[\(.workspace.name)] \(.class) - \(.title) ::: \(.address)"' \
                | kryonix-menu --prompt 'Janelas> ' --only-match
            )" || exit 0

            [ -n "$selection" ] || exit 0
            address="''${selection##*::: }"
            exec hyprctl dispatch focuswindow "address:$address"
          '';
        })

        (writeShellApplication {
          name = "kryonix-calc-menu";
          runtimeInputs = [
            bash
            coreutils
            kryonixMenu
            libqalculate
            wl-clipboard
            libnotify
          ];
          text = ''
            set -euo pipefail
            expr="$(printf '\n' | kryonix-menu --prompt 'qalc> ' --query | head -n1)" || exit 0
            [ -n "$expr" ] || exit 0

            result="$(qalc -t "$expr" | tail -n 1)" || exit 1
            printf '%s' "$result" | wl-copy
            notify-send -a "qalc" "Resultado copiado" "$result"
          '';
        })

        (writeShellApplication {
          name = "kryonix-quick-actions";
          runtimeInputs = [
            bash
            coreutils
            kryonixMenu
            libnotify
          ];
          text = ''
            set -euo pipefail

            backend="${if shellBackend == null then "none" else shellBackend}"

            case "$backend" in
              caelestia)
                if command -v kryonix-ipc >/dev/null 2>&1 && kryonix-ipc controlCenter open; then
                  exit 0
                fi
                ;;
            esac
            choice="$(printf '%s\n' \
              'Launcher do shell' \
              'Terminal' \
              'Arquivos' \
              'Janelas' \
              'Calculadora' \
              'Captura de tela' \
              'Gravar tela' \
              'Clipboard' \
              'Áudio' \
              'Rede/Bluetooth' \
              'Power' \
              'Copiar cor' \
              | kryonix-menu --prompt 'Kryonix> ' --only-match)" || exit 0

            case "$choice" in
              "Launcher do shell")
                exec kryonix-shell-launcher
                ;;
              "Terminal")
                exec uwsm app -- kryonix-terminal
                ;;
              "Arquivos")
                exec uwsm app -- dolphin
                ;;
              "Janelas")
                exec kryonix-window-menu
                ;;
              "Calculadora")
                exec kryonix-calc-menu
                ;;
              "Captura de tela")
                exec kryonix-screenshot edit-area
                ;;
              "Gravar tela")
                exec kryonix-record-menu
                ;;
              "Clipboard")
                exec kryonix-clipboard-menu
                ;;
              "Áudio")
                exec kryonix-audio-menu
                ;;
              "Rede/Bluetooth")
                exec kryonix-network-menu
                ;;
              "Power")
                exec kryonix-power-menu
                ;;
              "Copiar cor")
                exec hyprpicker -a
                ;;
              *)
                exit 0
                ;;
            esac
          '';
        })

      ];
      # Tema de cursor consistente em todos os aplicativos.
      home.pointerCursor = {
        gtk.enable = true;
        x11.enable = true;
        package = config.gtk.cursorTheme.package;
        name = config.gtk.cursorTheme.name;
        size = 24;
      };

      # Hyprland via Home Manager.
      wayland.windowManager.hyprland = {
        enable = true;

        # CRÍTICO: variables = ["--all"] exporta WAYLAND_DISPLAY, DISPLAY e todas as
        # variáveis de ambiente do Hyprland para o systemd-user e o D-Bus.
        # Sem isso, serviços como waybar/cliphist/swaync esperam indefinidamente
        # até o timeout de 60s do systemd antes de continuar.
        systemd = {
          enable = true;
          variables = [ "--all" ];
        };

        # Reaproveita o config versionado no repo.
        # O keyring é inicializado via PAM/NixOS, não manualmente por `exec-once`.
        extraConfig = builtins.readFile ./hyprland.conf;
      };

      # Publica a configuração do Hyprland a partir do store do Home Manager.
      xdg.configFile = lib.mkMerge [
        (lib.mkIf (!shellProvidesChrome) {
          "hypr/hyprpaper.conf".text = ''
            splash = false
            preload = ${config.wallpaper}
            wallpaper = , ${config.wallpaper}
          '';
        })
        {
          "hypr/hypridle.conf".text = ''
            general {
              # Usa hyprlock (não um script customizado) como comando de lock.
              # `pidof hyprlock ||` evita iniciar duas instâncias.
              lock_cmd = pidof hyprlock || hyprlock
              # Bloqueia VIA LOGIND antes de dormir (integração correta com systemd).
              before_sleep_cmd = loginctl lock-session
              # Re-liga displays após wakeup.
              after_sleep_cmd = hyprctl dispatch dpms on
              # Ignora idle ao reproduzir mídia fullscreen
              ignore_dbus_inhibit = false
            }

            # 3 min: dim displays
            listener {
              timeout = 150
              on-timeout = brightnessctl -s set 20%
              on-resume  = brightnessctl -r
            }

            # 5 min: bloquear tela
            listener {
              timeout = 300
              on-timeout = loginctl lock-session
              on-resume  = hyprctl dispatch dpms on
            }

            # 10 min: desligar displays (economiza bateria)
            listener {
              timeout = 600
              on-timeout = ${runIfOnBattery} hyprctl dispatch dpms off
              on-resume  = hyprctl dispatch dpms on
            }

            # 30 min: suspender sistema
            listener {
              timeout = 1800
              on-timeout = ${runIfOnBattery} systemctl suspend
            }
          '';

          # hyprlock: tela de bloqueio completa com blur + relógio
          "hypr/hyprlock.conf".text = ''
            general {
              grace     = 2       # segundos de grace period (teclado visível)
              hide_cursor = true
              no_fade_in  = false
              no_fade_out = false
              pam_module  = hyprlock
            }

            # Fundo com blur
            background {
              monitor =
              path    = screenshot
              blur_passes  = 3
              blur_size    = 7
              noise        = 0.0117
              contrast     = 0.8916
              brightness   = 0.8172
              vibrancy     = 0.1696
              vibrancy_darkness = 0.0
            }

            # Relógio grande centralizado
            label {
              monitor =
              text     = cmd[update:1000] echo "$(date +"%-H:%M:%S")"
              color    = rgba(207, 213, 245, 1.0)
              font_size   = 90
              font_family = Monocraft
              position    = 0, 80
              halign      = center
              valign      = center
              shadow_passes = 2
              shadow_size   = 4
            }

            # Data
            label {
              monitor =
              text     = cmd[update:10000] echo "$(date +"%A, %d de %B")"
              color    = rgba(166, 173, 200, 0.8)
              font_size   = 18
              font_family = Monocraft
              position    = 0, -15
              halign      = center
              valign      = center
              shadow_passes = 2
              shadow_size   = 2
            }

            # Campo de senha
            input-field {
              monitor =
              size     = 250, 50
              outline_thickness = 2
              dots_size    = 0.26
              dots_spacing = 0.64
              dots_center  = true
              outer_color  = rgba(138, 133, 193, 1.0)
              inner_color  = rgba(26, 27, 38, 0.85)
              font_color   = rgba(207, 213, 245, 1.0)
              fade_on_empty = true
              placeholder_text = <span foreground="##a9b1d6" font_size="small">Senha...</span>
              rounding     = 12
              check_color  = rgba(115, 218, 202, 1.0)
              fail_color   = rgba(247, 118, 142, 1.0)
              fail_text    = <i>Senha incorreta :(</i>
              fail_timeout = 2000
              capslock_color = rgba(255, 158, 100, 1.0)
              position = 0, -200
              halign   = center
              valign   = center
            }
          '';
        }
      ];

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
    }
  ];
}
