{
  pkgs,
  lib,
  modulesPath,
  ragcPkg ? null,
  ...
}:

let
  normalizeText = text: builtins.replaceStrings [ "\r\n" ] [ "\n" ] text;
  ragosSrc = lib.cleanSourceWith {
    src = ../.;
    filter =
      path: type:
      let
        pathStr = toString path;
        srcStr = toString ../.;
        rel =
          if lib.hasPrefix (srcStr + "/") pathStr then
            lib.removePrefix (srcStr + "/") pathStr
          else
            baseNameOf pathStr;
        parts = lib.splitString "/" rel;
      in
      !builtins.any (
        part:
        builtins.elem part [
          ".git"
          ".direnv"
          "node_modules"
          "target"
        ]
        || builtins.match "result(-.*)?" part != null
      ) parts;
  };
  installerRuntimeInputs = with pkgs; [
    bash
    coreutils
    gnugrep
    gnused
    gawk
    findutils
    util-linux
    iproute2
    parted
    gptfdisk
    dosfstools
    e2fsprogs
    btrfs-progs
    xfsprogs
    mdadm
    cryptsetup
    nfs-utils
    ppp
    openssh
    dialog
    newt
    git
    nix
    mkpasswd
    nixos-install-tools
    whois
    jq
    python3
    systemd
  ];

  ragosInstallerUi = pkgs.callPackage ./installer-ui/ragos-installer-ui.nix { };
  ragosWallpaper =
    pkgs.runCommand "ragos-installer-wallpaper.png"
      {
        nativeBuildInputs = [ pkgs.imagemagick ];
      }
      (normalizeText ''
        magick \
          -size 1920x1080 gradient:'#040b16-#123550' \
          \( -size 1920x1080 xc:none -fill 'rgba(120,196,255,0.14)' -draw 'circle 1480,180 1920,180' \) \
          -compose screen -composite \
          \( -size 1920x1080 xc:none -fill 'rgba(255,255,255,0.05)' -draw 'circle 280,900 760,900' \) \
          -compose screen -composite \
          \( ${./installer-ui/imgs/ragton.png} -resize 420x420 \) \
          -gravity center -geometry +0-40 -composite \
          $out
      '');

  ragosKioskFallbackPage = pkgs.writeText "ragos-installer-fallback.html" (normalizeText ''
    <!doctype html>
    <html lang="pt-BR">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>RAGOS Installer</title>
        <style>
          :root {
            color-scheme: dark;
            --panel: rgba(7, 12, 24, 0.86);
            --line: rgba(134, 197, 255, 0.18);
            --text: #f5f8ff;
            --muted: #9bb6d6;
            --accent: #78c4ff;
          }
          * { box-sizing: border-box; }
          body {
            margin: 0;
            min-height: 100vh;
            font-family: "Noto Sans", "DejaVu Sans", sans-serif;
            color: var(--text);
            background:
              linear-gradient(rgba(4, 8, 18, 0.72), rgba(4, 8, 18, 0.84)),
              url("file://${ragosWallpaper}") center/cover no-repeat fixed;
            display: grid;
            place-items: center;
            overflow: hidden;
          }
          .panel {
            width: min(860px, calc(100vw - 96px));
            padding: 36px 40px;
            background: var(--panel);
            border: 1px solid var(--line);
            border-radius: 22px;
            box-shadow: 0 24px 80px rgba(0, 0, 0, 0.45);
            backdrop-filter: blur(18px);
          }
          .brand {
            display: flex;
            align-items: center;
            gap: 18px;
            margin-bottom: 28px;
          }
          .brand img {
            width: 76px;
            height: 76px;
          }
          h1 {
            margin: 0;
            font-size: 34px;
            line-height: 1.05;
          }
          p {
            margin: 0;
            color: var(--muted);
            font-size: 18px;
            line-height: 1.6;
          }
          .status {
            margin-top: 28px;
            padding: 18px 20px;
            border-radius: 16px;
            background: rgba(120, 196, 255, 0.08);
            border: 1px solid rgba(120, 196, 255, 0.16);
          }
          .spinner {
            width: 20px;
            height: 20px;
            border-radius: 999px;
            border: 3px solid rgba(120, 196, 255, 0.18);
            border-top-color: var(--accent);
            animation: spin 1s linear infinite;
            display: inline-block;
            vertical-align: middle;
            margin-right: 12px;
          }
          .hint {
            margin-top: 18px;
            font-size: 14px;
            color: #86a5c9;
          }
          @keyframes spin {
            to { transform: rotate(360deg); }
          }
        </style>
      </head>
      <body>
        <main class="panel">
          <div class="brand">
            <img src="file://${./installer-ui/imgs/ragton.png}" alt="RAGOS">
            <div>
              <h1>RAGOS Installer</h1>
              <p>Inicializando o ambiente de instalacao dedicado.</p>
            </div>
          </div>
          <div class="status">
            <span class="spinner"></span>
            <strong>Tentando abrir o instalador...</strong>
            <p style="margin-top: 10px;">A interface sera exibida automaticamente quando a UI local responder.</p>
          </div>
          <p class="hint">Se esta tela permanecer por muito tempo, a sessao kiosk tentara reiniciar o navegador em segundo plano.</p>
        </main>
        <script>
          async function probe() {
            try {
              const res = await fetch("http://127.0.0.1:8000/api/v1/status", { cache: "no-store" });
              if (res.ok) {
                window.location.replace("http://127.0.0.1:8000");
                return;
              }
            } catch (error) {
            }
            window.setTimeout(probe, 1500);
          }
          window.setTimeout(probe, 300);
        </script>
      </body>
    </html>
  '');

  ragosKioskBrowser = pkgs.writeShellApplication {
    name = "ragos-kiosk-browser";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      curl
      feh
      yad
      chromium
      fontconfig
      systemd
      xorg.xset
    ];
    text = normalizeText ''
      set -eu

        export HOME=/home/ragos
        export XDG_CONFIG_HOME=/home/ragos/.config
        export XDG_CACHE_HOME=/home/ragos/.cache
        export FONTCONFIG_FILE=/etc/fonts/fonts.conf
        export FONTCONFIG_PATH=/etc/fonts
        export RAGOS_KIOSK_LOG_FILE="''${RAGOS_KIOSK_LOG_FILE:-/run/ragos/kiosk-browser.log}"

        mkdir -p /run/ragos/kiosk-profile "$HOME/.config" "$HOME/.cache"
        chmod 700 /run/ragos/kiosk-profile "$HOME/.config" "$HOME/.cache"
        : >"$RAGOS_KIOSK_LOG_FILE"
        exec >>"$RAGOS_KIOSK_LOG_FILE" 2>&1

      log() {
        printf '[%s] %s\n' "$(date -Is)" "$*"
      }

      log "Starting kiosk browser"
      log "PATH=$PATH"
      log "USER=''${USER:-unknown} UID=$(id -u)"
      log "FONTCONFIG_FILE=$FONTCONFIG_FILE"
      log "FONTCONFIG_PATH=$FONTCONFIG_PATH"

      feh --no-fehbg --bg-fill ${ragosWallpaper} || true
        xset -dpms || true
        xset s off || true
        xset s noblank || true

        if [[ -L /opt/ragos-src || -d /opt/ragos-src ]]; then
          log "Live source bridge present at /opt/ragos-src"
        else
          log "Warning: /opt/ragos-src is missing"
        fi

        if [[ -r "$FONTCONFIG_FILE" ]]; then
          fc-match Sans || true
        else
          log "Warning: missing fontconfig file at $FONTCONFIG_FILE"
        fi

      show_fallback_dialog() {
        yad \
          --title="RAGOS Installer" \
          --undecorated \
          --fullscreen \
          --center \
          --skip-taskbar \
          --on-top \
          --no-escape \
          --image="${./installer-ui/imgs/ragton.png}" \
          --text="<span font='18' foreground='#F5F8FF'><b>Falha ao abrir o instalador grafico</b></span>\n\nA sessao kiosk do RAGOS nao conseguiu manter a interface principal ativa.\n\nEscolha uma acao para continuar." \
          --text-align=center \
          --buttons-layout=center \
          --button="Tentar novamente:0" \
          --button="Reiniciar sistema:2" \
          --button="Desligar:3" || return $?
      }

      launch_target() {
        local target
        target="file://${ragosKioskFallbackPage}"
        if curl -fsS http://127.0.0.1:8000/api/v1/status >/dev/null 2>&1; then
          target="http://127.0.0.1:8000"
        fi

        log "Launching Chromium target=$target"
        chromium \
          --kiosk \
          --app="$target" \
          --incognito \
          --user-data-dir=/run/ragos/kiosk-profile \
          --no-first-run \
          --no-default-browser-check \
          --disable-session-crashed-bubble \
          --disable-infobars \
          --disable-features=Translate,MediaRouter,ChromeWhatsNewUI \
          --overscroll-history-navigation=0 \
          --noerrdialogs \
          --check-for-update-interval=31536000
      }

      while true; do
        launch_target || true
        log "Chromium exited; showing fallback dialog"
        feh --no-fehbg --bg-fill ${ragosWallpaper} || true
        fallback_status=0
        show_fallback_dialog || fallback_status=$?
        case "$fallback_status" in
          2)
            exec systemctl reboot
            ;;
          3)
            exec systemctl poweroff
            ;;
          *)
            sleep 2
            ;;
        esac
      done
    '';
  };

  ragosOpenboxAutostart = pkgs.writeShellApplication {
    name = "ragos-openbox-autostart";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      curl
      feh
      util-linux
      xorg.xset
      xorg.xsetroot
      systemd
      ragosKioskBrowser
    ];
    text = normalizeText ''
      set -eu

      export HOME=/home/ragos
      export USER=ragos
      export LOGNAME=ragos
      export XDG_CONFIG_HOME=/home/ragos/.config
      export XDG_CACHE_HOME=/home/ragos/.cache
      export RAGOS_GRAPHICAL_LOG_FILE="''${RAGOS_GRAPHICAL_LOG_FILE:-/run/ragos/graphical-session.log}"
      export RAGOS_KIOSK_LOG_FILE="''${RAGOS_KIOSK_LOG_FILE:-/run/ragos/kiosk-browser.log}"

      mkdir -p /run/ragos "$HOME/.config/openbox" "$HOME/.cache"
      chmod 700 "$HOME/.config" "$HOME/.cache"
      : >"$RAGOS_GRAPHICAL_LOG_FILE"
      exec >>"$RAGOS_GRAPHICAL_LOG_FILE" 2>&1

      log() {
        printf '[%s] %s\n' "$(date -Is)" "$*"
      }

      log "Openbox autostart init"
      log "PATH=$PATH"
      log "USER=''${USER:-unknown} UID=$(id -u)"
      log "DISPLAY=''${DISPLAY:-unset}"

      if [[ -L /opt/ragos-src || -d /opt/ragos-src ]]; then
        log "Live source bridge present at /opt/ragos-src"
      else
        log "Warning: /opt/ragos-src is missing"
      fi

      xsetroot -solid "#071a2f" || true
      xset -dpms || true
      xset s off || true
      xset s noblank || true
      feh --no-fehbg --bg-fill ${ragosWallpaper} || true

      log "Waiting for ragos-installer-ui.service"
      for _ in $(seq 1 60); do
        if curl -fsS http://127.0.0.1:8000/api/v1/status >/dev/null 2>&1; then
          log "Installer UI became reachable"
          break
        fi
        sleep 1
      done

      log "Launching kiosk browser"
      ragos-kiosk-browser &
    '';
  };

  ragosInstall = pkgs.writeShellApplication {
    name = "ragos-install";
    runtimeInputs =
      installerRuntimeInputs
      ++ (with pkgs; [
        feh
        xterm
        yad
        curl
      ]);
    text = normalizeText ''
      export RAGOS_INSTALLER_DIR=${./.}
      exec ${pkgs.bash}/bin/bash ${./bin/ragos-install} "$@"
    '';
  };

  ragosInstallRunner = pkgs.writeShellApplication {
    name = "ragos-install-runner";
    runtimeInputs = [ ragosInstall ];
    text = normalizeText ''
      set -euo pipefail

      if [[ "''${1:-}" != "unattended" ]]; then
        exec ragos-install "$@"
      fi

      shift || true
      ragos-install preflight-unattended "$@"
      exec ragos-install unattended "$@"
    '';
  };

  ragosCli = pkgs.writeShellApplication {
    name = "ragos-cli";
    runtimeInputs = [ ragosInstall ];
    text = normalizeText ''
      set -euo pipefail
      case "''${1:-}" in
        install)
          exec ragos-install terminal
          ;;
        install-gui)
          exec ragos-install graphical
          ;;
        *)
          echo "Uso: ragos-cli {install|install-gui}" >&2
          exit 2
          ;;
      esac
    '';
  };

  ragosTerminalLauncher = pkgs.writeShellApplication {
    name = "ragos-terminal-launcher";
    runtimeInputs =
      installerRuntimeInputs
      ++ (with pkgs; [
        bashInteractive
        ncurses
      ]);
    text = normalizeText ''
      set -euo pipefail

      export HOME=/root
      export USER=root
      export LOGNAME=root
      export TERM=linux
      export RAGOS_BOOT_LOG_FILE=/run/ragos-boot-dispatcher.log
      export RAGOS_INSTALL_LOG_FILE=/run/ragos-terminal.log
      export RAGOS_INSTALLER_UI=plain

      mkdir -p /run/ragos /opt
      exec </dev/tty1 >/dev/tty1 2>&1
      exec > >(tee -a "$RAGOS_BOOT_LOG_FILE" >/dev/tty1) 2>&1

      log() {
        printf '[%s] %s\n' "$(date -Is)" "$*"
      }

      banner() {
        clear
        printf '\033[1;34m%s\033[0m\n\n' "$1"
      }

      if [[ -d /iso/opt/ragos-src ]]; then
        ln -sfn /iso/opt/ragos-src /opt/ragos-src
      fi

      stty sane cols 120 rows 40 >/dev/null 2>&1 || true
      log "cmdline: $(cat /proc/cmdline)"
      log "tty=$(tty || echo unknown) user=$USER uid=$(id -u) PATH=$PATH"
      log "branch=terminal plain-text"

      banner "RAGOS Installer (Terminal)"
      printf 'Inicializando o instalador em modo texto...\n\n'
      exec ragos-install terminal
    '';
  };

in
{
  disabledModules = [ "${modulesPath}/installer/cd-dvd/iso-image.nix" ];

  imports = [
    ./iso-image-ragos.nix
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    ./iso-base.nix
    ./iso-kiosk.nix
    ./iso-users.nix
    ./iso-network.nix
    ./iso-branding.nix
  ];

  _module.args = {
    inherit
      normalizeText
      ragosSrc
      installerRuntimeInputs
      ragosInstallerUi
      ragosWallpaper
      ragosKioskFallbackPage
      ragosKioskBrowser
      ragosOpenboxAutostart
      ragosInstall
      ragosInstallRunner
      ragosCli
      ragosTerminalLauncher
      ragcPkg
      ;
  };
}
