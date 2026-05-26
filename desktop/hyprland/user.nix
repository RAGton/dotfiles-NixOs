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
    ./theme
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

        # CRÍTICO: "hyprlang" gera hyprland.conf (formato conf nativo).
        # "lua" (padrão no stateVersion atual) gera hyprland.lua e exige que
        # extraConfig seja código Lua, incompatível com o hyprland.conf versionado.
        configType = "hyprlang";

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
