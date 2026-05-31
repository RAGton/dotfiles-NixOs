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
    ./core/monitors.nix
    ./core/rules.nix
    ./core/keybinds.nix
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

      xdg.mimeApps = {
        enable = true;
        defaultApplications = {
          # Imagens
          "inode/directory"               = [ "org.kde.dolphin.desktop" ];
          "image/jpeg"                    = [ "org.kde.gwenview.desktop" ];
          "image/jpg"                     = [ "org.kde.gwenview.desktop" ];
          "image/png"                     = [ "org.kde.gwenview.desktop" ];
          "image/x-png"                   = [ "org.kde.gwenview.desktop" ];
          "image/gif"                     = [ "org.kde.gwenview.desktop" ];
          "image/webp"                    = [ "org.kde.gwenview.desktop" ];
          "image/bmp"                     = [ "org.kde.gwenview.desktop" ];
          "image/tiff"                    = [ "org.kde.gwenview.desktop" ];
          "image/heic"                    = [ "org.kde.gwenview.desktop" ];
          "image/avif"                    = [ "org.kde.gwenview.desktop" ];
          "image/svg+xml"                 = [ "org.gimp.GIMP.desktop" "org.kde.gwenview.desktop" ];

          # Vídeo
          "video/mp4"                     = [ "mpv.desktop" ];
          "video/x-matroska"              = [ "mpv.desktop" ];
          "video/webm"                    = [ "mpv.desktop" ];
          "video/avi"                     = [ "mpv.desktop" ];
          "video/quicktime"               = [ "mpv.desktop" ];
          "video/x-msvideo"               = [ "mpv.desktop" ];
          "video/mpeg"                    = [ "mpv.desktop" ];
          "video/ogg"                     = [ "mpv.desktop" ];
          "video/flv"                     = [ "mpv.desktop" ];
          "video/x-flv"                   = [ "mpv.desktop" ];
          "video/mp2t"                    = [ "mpv.desktop" ];
          "video/3gpp"                    = [ "mpv.desktop" ];
          "video/3gpp2"                   = [ "mpv.desktop" ];

          # Áudio
          "audio/mpeg"                    = [ "mpv.desktop" ];
          "audio/mp3"                     = [ "mpv.desktop" ];
          "audio/flac"                    = [ "mpv.desktop" ];
          "audio/ogg"                     = [ "mpv.desktop" ];
          "audio/x-vorbis+ogg"            = [ "mpv.desktop" ];
          "audio/wav"                     = [ "mpv.desktop" ];
          "audio/x-wav"                   = [ "mpv.desktop" ];
          "audio/aac"                     = [ "mpv.desktop" ];
          "audio/opus"                    = [ "mpv.desktop" ];
          "audio/mp4"                     = [ "mpv.desktop" ];
          "audio/x-m4a"                   = [ "mpv.desktop" ];
          "audio/webm"                    = [ "mpv.desktop" ];

          # PDF e documentos
          "application/pdf"               = [ "org.kde.okular.desktop" ];
          "application/epub+zip"          = [ "org.kde.okular.desktop" ];
          "application/postscript"        = [ "org.kde.okular.desktop" ];
          "image/x-eps"                   = [ "org.kde.okular.desktop" ];

          # Texto e código
          "text/plain"                    = [ "org.kde.kate.desktop" ];
          "text/markdown"                 = [ "org.kde.kate.desktop" ];
          "text/x-python"                 = [ "org.kde.kate.desktop" ];
          "text/x-shellscript"            = [ "org.kde.kate.desktop" ];
          "text/x-script.python"          = [ "org.kde.kate.desktop" ];
          "text/css"                      = [ "org.kde.kate.desktop" ];
          "text/html"                     = [ "app.zen_browser.zen.desktop" ];
          "text/xml"                      = [ "org.kde.kate.desktop" ];
          "text/x-lua"                    = [ "org.kde.kate.desktop" ];
          "application/json"              = [ "org.kde.kate.desktop" ];
          "application/xml"               = [ "org.kde.kate.desktop" ];
          "application/javascript"        = [ "org.kde.kate.desktop" ];

          # Web
          "x-scheme-handler/http"         = [ "app.zen_browser.zen.desktop" ];
          "x-scheme-handler/https"        = [ "app.zen_browser.zen.desktop" ];
          "x-scheme-handler/ftp"          = [ "app.zen_browser.zen.desktop" ];
          "x-scheme-handler/chrome"       = [ "app.zen_browser.zen.desktop" ];
          "x-scheme-handler/mailto"       = [ "app.zen_browser.zen.desktop" ];
          "application/xhtml+xml"         = [ "app.zen_browser.zen.desktop" ];
          "application/x-extension-htm"   = [ "app.zen_browser.zen.desktop" ];
          "application/x-extension-html"  = [ "app.zen_browser.zen.desktop" ];
          "application/x-extension-xhtml" = [ "app.zen_browser.zen.desktop" ];
          "application/x-extension-xht"   = [ "app.zen_browser.zen.desktop" ];

          # Arquivos compactados
          "application/zip"               = [ "org.kde.ark.desktop" ];
          "application/x-tar"             = [ "org.kde.ark.desktop" ];
          "application/gzip"              = [ "org.kde.ark.desktop" ];
          "application/x-gzip"            = [ "org.kde.ark.desktop" ];
          "application/x-bzip2"           = [ "org.kde.ark.desktop" ];
          "application/x-xz"              = [ "org.kde.ark.desktop" ];
          "application/x-7z-compressed"   = [ "org.kde.ark.desktop" ];
          "application/x-rar"             = [ "org.kde.ark.desktop" ];
          "application/x-rar-compressed"  = [ "org.kde.ark.desktop" ];
          "application/vnd.rar"           = [ "org.kde.ark.desktop" ];
          "application/zstd"              = [ "org.kde.ark.desktop" ];
          "application/x-compressed-tar"  = [ "org.kde.ark.desktop" ];
          "application/x-bzip-compressed-tar" = [ "org.kde.ark.desktop" ];
          "application/x-xz-compressed-tar"   = [ "org.kde.ark.desktop" ];
          "application/x-zstd-compressed-tar" = [ "org.kde.ark.desktop" ];

          # Office / LibreOffice
          "application/vnd.oasis.opendocument.text"         = [ "writer.desktop" ];
          "application/vnd.oasis.opendocument.spreadsheet"  = [ "calc.desktop" ];
          "application/vnd.oasis.opendocument.presentation" = [ "impress.desktop" ];
          "application/msword"                              = [ "writer.desktop" ];
          "application/vnd.ms-excel"                        = [ "calc.desktop" ];
          "application/vnd.ms-powerpoint"                   = [ "impress.desktop" ];
          "application/vnd.openxmlformats-officedocument.wordprocessingml.document"   = [ "writer.desktop" ];
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"         = [ "calc.desktop" ];
          "application/vnd.openxmlformats-officedocument.presentationml.presentation" = [ "impress.desktop" ];
        };
      };

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

        # CRÍTICO: Com o UWSM ativo, o gerenciamento do systemd (variáveis, targets)
        # é feito nativamente por ele. Deixar a integração do Home Manager ligada
        # causa conflitos e um atraso absurdo (timeout) na inicialização após o SDDM.
        systemd.enable = false;

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
          "kdeglobals".text = ''
            [KDE]
            SingleClick=false

            [PreviewSettings]
            EnableRemoteFolderThumbnail=false
            MaximumRemoteSize=0
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
