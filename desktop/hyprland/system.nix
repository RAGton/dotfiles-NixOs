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

  mkHyprlandNoNixGL =
    hyprlandPkg:
    let
      wrapped =
        pkgs.runCommand "${hyprlandPkg.name}-no-nixgl"
          {
            nativeBuildInputs = [ pkgs.makeWrapper ];
            outputs = [
              "out"
              "dev"
              "man"
            ];
            pname = (hyprlandPkg.pname or "hyprland") + "-no-nixgl";
            version = hyprlandPkg.version;
            meta = hyprlandPkg.meta;
            passthru = hyprlandPkg.passthru or { };
          }
          ''
            mkdir -p "$out" "$dev" "$man"

            cp -a ${hyprlandPkg}/. "$out/"
            chmod -R u+w "$out"
            rm -f "$out/bin/start-hyprland"
            makeWrapper ${hyprlandPkg}/bin/start-hyprland "$out/bin/start-hyprland" \
              --add-flags --no-nixgl

            cp -a ${hyprlandPkg.dev}/. "$dev/"
            chmod -R u+w "$dev"
            cp -a ${hyprlandPkg.man}/. "$man/"
            chmod -R u+w "$man"
          '';
    in
    wrapped
    // {
      override = args: mkHyprlandNoNixGL (hyprlandPkg.override args);
      overrideAttrs = f: mkHyprlandNoNixGL (hyprlandPkg.overrideAttrs f);
    };

  hyprlandNoNixGL = mkHyprlandNoNixGL pkgs.hyprland;
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

    services.displayManager = {
      sddm.enable = lib.mkForce false;
      gdm = {
        enable = lib.mkForce (!config.kryonix.desktop.directLogin.enable);
        wayland = true;
      };

      defaultSession = "hyprland-uwsm";
      sessionPackages = [ hyprlandNoNixGL ];

      # Disable DM autologin somente quando NÃO usamos DM (directLogin)
      autoLogin.enable = lib.mkIf (config.kryonix.desktop.directLogin.enable or false) (
        lib.mkForce false
      );
    };

    services.xserver.displayManager.lightdm.enable = lib.mkForce false;

    # Hyprland
    programs.hyprland = {
      enable = true;
      package = hyprlandNoNixGL;
      # UWSM: mantém ambiente/DBus/systemd-user consistentes na sessão Wayland.
      # (GDM também enxerga `hyprland-uwsm.desktop` quando isto está habilitado.)
      withUWSM = lib.mkDefault true;
      xwayland.enable = true;
    };

    # Screenshot stack (Wayland nativo) + wrapper estável para binds.
    environment.systemPackages = with pkgs; [
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
        name = "kryonix-screenshot";
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
              echo "Uso: kryonix-screenshot {copy-area|copysave-screen|copysave-active|edit-area|edit-output}" >&2
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
