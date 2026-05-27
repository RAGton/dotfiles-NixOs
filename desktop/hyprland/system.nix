{
  config,
  lib,
  pkgs,
  userConfig ? null,
  ...
}:

let
  isHyprland = config.kryonix.desktop.environment == "hyprland";

  directLoginEnabled = (config.kryonix.desktop.directLogin.enable or false) && userConfig != null;
  directLoginTtyNumber = toString (config.kryonix.desktop.directLogin.tty or 1);
  directLoginTty = "tty${directLoginTtyNumber}";

  hyprlandNoNixGL = pkgs.hyprland;
in
{
  config = lib.mkIf isHyprland {

    # DirectLogin: autologin APENAS no TTY escolhido (sem display manager)
    # Importante: `services.getty.autologinUser` é global e acaba logando o usuário em TODOS os TTYs.
    systemd.services."getty@${directLoginTty}" = lib.mkIf directLoginEnabled {
      serviceConfig.ExecStart = [
        ""
        "${pkgs.util-linux}/sbin/agetty --autologin ${userConfig.name} --login-program ${pkgs.shadow}/bin/login --noclear --keep-baud 115200,38400,9600 %I $TERM"
      ];
    };

    # Boot direto (sem display manager): ao logar no TTY escolhido, inicia Hyprland via UWSM.
    # Mantemos isso no nível do sistema para funcionar mesmo sem `home-manager switch`.
    # Só inicia Hyprland automaticamente quando não há display manager.
    programs.zsh.loginShellInit = lib.mkIf (config.kryonix.desktop.directLogin.enable) (
      lib.mkAfter ''
        if [[ -z "''${WAYLAND_DISPLAY-}" && -z "''${DISPLAY-}" && "''${XDG_VTNR-}" = "${directLoginTtyNumber}" ]]; then
          if command -v uwsm >/dev/null 2>&1; then
            exec uwsm start hyprland || exec uwsm start hyprland-uwsm.desktop
          fi
          exec Hyprland
        fi
      ''
    );

    # Kill greetd em qualquer modo do stack Hyprland (proibido aqui)
    services.greetd.enable = lib.mkForce false;

    services.xserver.enable = true;

    systemd.services.display-manager.serviceConfig = {
      StartLimitBurst = 3;
      StartLimitIntervalSec = 60;
    };

    services.displayManager = {
      sddm = {
        wayland.enable = true;
        # compositor padrão é "weston" (standalone). NÃO definir "kwin" (exige plasma6).
        theme = "sddm-astronaut-theme";

        # Main.qml:10 importa QtMultimedia — necessário para o tema astronaut (Qt6)
        extraPackages = [ pkgs.kdePackages.qtmultimedia ];

        settings = {
          Theme = {
            Background = "/var/lib/sddm/current-wallpaper";
            ThemeDir = "/run/current-system/sw/share/sddm/themes";
            CursorTheme = "Bibata-Modern-Ice";
            CursorSize = 24;
            ThemeConfig = "/etc/kryonix/files/sddm/astronaut-theme.conf";
          };
          General = {
            Font = "JetBrains Mono";
            FontSize = 12;
          };
        };
      };

      defaultSession = "hyprland-uwsm";
      sessionPackages = [ hyprlandNoNixGL ];

      # Disable DM autologin somente quando NÃO usamos DM (directLogin)
      autoLogin.enable = lib.mkIf (config.kryonix.desktop.directLogin.enable or false) (
        lib.mkForce false
      );
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/sddm 0755 sddm sddm -"
    ];

    systemd.services.sddm-random-wallpaper = {
      description = "Sorteia wallpaper aleatório para o SDDM";
      before   = [ "display-manager.service" ];
      wantedBy = [ "display-manager.service" ];
      path = [ pkgs.coreutils ];
      serviceConfig = {
        Type      = "oneshot";
        ExecStart = pkgs.writeShellScript "sddm-random-wallpaper" ''
          WALL_DIR="/etc/kryonix/files/wallpaper"
          LINK="/var/lib/sddm/current-wallpaper"
          img=$(ls "$WALL_DIR"/*.{png,jpg,webp} 2>/dev/null | shuf -n1)
          [ -n "$img" ] && ln -sf "$img" "$LINK" && echo "SDDM wallpaper: $img"
        '';
      };
    };

    # Hyprland
    programs.hyprland = {
      enable = true;
      package = hyprlandNoNixGL;
      # UWSM: mantém ambiente/DBus/systemd-user consistentes na sessão Wayland.
      # (GDM também enxerga `hyprland-uwsm.desktop` quando isto está habilitado.)
      withUWSM = lib.mkDefault true;
      xwayland.enable = true;
    };

    # Portals: crítico para evitar delays em abertura de apps e diálogos.
    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gtk
      ];
      config = {
        common.default = [ "gtk" ];
        hyprland.default = [
          "hyprland"
          "gtk"
        ];
      };
    };

    # Screenshot stack (Wayland nativo) + wrapper estável para binds.
    environment.systemPackages = with pkgs; [
      sddm-astronaut
      bibata-cursors
      nerd-fonts.jetbrains-mono
      grim
      slurp
      wl-clipboard
      swappy
      libnotify
      jq
      hyprlandNoNixGL

      # `grimblast` (wrapper declarativo)
      # - Mantém UX compatível com os binds esperados.
      # - Implementa apenas o subset necessário de forma estável no Wayland/Hyprland.
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
          hyprlandNoNixGL
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
              # Captura janela ativa via hyprctl (x,y,w,h) => grim -g
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
        name = "rag-screenshot";
        runtimeInputs = [
          bash
          coreutils
          grim
          slurp
          wl-clipboard
          swappy
          libnotify
          jq
          hyprlandNoNixGL
          grimblast
        ];
        text = ''
          set -euo pipefail

          action="''${1-}"
          shift || true

          screenshots_dir="''${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
          mkdir -p "$screenshots_dir"

          ts="$(date +%F_%H-%M-%S)"
          file="$screenshots_dir/Screenshot_$ts.png"

          notify() {
            # notify-send vem de libnotify
            notify-send -a "screenshot" "$@" >/dev/null 2>&1 || true
          }

          case "$action" in
            copy-area)
              grimblast --notify copy area
              ;;

            copysave-screen)
              grim "$file"
              wl-copy < "$file"
              notify "Screenshot" "Tela salva e copiada: $(basename "$file")"
              ;;

            copysave-active)
              exec grimblast --notify copysave active
              ;;

            edit-area)
              tmp="''${TMPDIR:-/tmp}/screenshot-area-$ts.png"
              geometry="$(slurp)" || exit 0
              [[ -n "$geometry" ]] || exit 0
              grim -g "$geometry" "$tmp"
              exec swappy -f "$tmp"
              ;;

            edit-output)
              # fallback estável: captura tela inteira e abre no swappy
              tmp="''${TMPDIR:-/tmp}/screenshot-screen-$ts.png"
              grim "$tmp"
              exec swappy -f "$tmp"
              ;;

            *)
              echo "Uso: rag-screenshot {copy-area|copysave-screen|copysave-active|edit-area|edit-output}" >&2
              exit 2
              ;;
          esac
        '';
      })
    ];

    assertions = [
      {
        assertion = !config.services.greetd.enable;
        message = "greetd must not be enabled in the Hyprland stack.";
      }
    ];
  };
}
