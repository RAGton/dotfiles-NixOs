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
  runIfOnBattery = pkgs.writeShellScript "rag-run-if-on-battery" ''
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
in
{
  imports = [
    "${nhModules}/misc/gtk"
    "${nhModules}/misc/qt"
    "${nhModules}/misc/wallpaper"
    "${nhModules}/misc/xdg"
    "${nhModules}/programs/swappy"
    ./monitors.nix
    ./wrappers.nix
  ];

  config = lib.mkMerge [
    {
      # Monitores: voltar ao padrão do shell/Hyprland (sem kanshi forçando scale/posições).
      services.kanshi.enable = lib.mkForce false;

      # Screenshot stack (Wayland nativo) no nível do usuário, para os binds funcionarem
      # mesmo antes de um `nixos-rebuild`.
      home.packages = with pkgs; [
        hyprpicker
        wf-recorder
        libqalculate
        brightnessctl
        kdePackages.ark
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
