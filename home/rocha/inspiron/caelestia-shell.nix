{ pkgs, ... }:
let
  koraStatusPkg = pkgs.writeShellApplication {
    name = "kryonix-kora-status";
    runtimeInputs = with pkgs; [ curl gnugrep coreutils ];
    text = ''
      KORA_URL="''${KORA_API_URL:-http://glacier:8787}"
      TIMEOUT=2
      HEALTH_FILE=$(mktemp)
      trap 'rm -f "$HEALTH_FILE"' EXIT

      if curl -sf --max-time "$TIMEOUT" "$KORA_URL/health" > "$HEALTH_FILE" 2>/dev/null; then
        brain=$(grep -o '"brain":[^,}]*' "$HEALTH_FILE" | grep -o 'true\|ok\|healthy' || true)
        if [ -n "$brain" ]; then
          echo "⟡ KORA ONLINE"
        else
          echo "⟡ KORA ◈ BRAIN OFF"
        fi
      else
        echo "◈ KORA OFFLINE"
      fi
    '';
  };

  koraMonitorPkg = pkgs.writeShellApplication {
    name = "kryonix-kora-monitor";
    runtimeInputs = with pkgs; [ curl libnotify coreutils ];
    text = ''
      STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/kryonix"
      STATE_FILE="$STATE_DIR/kora-state"
      KORA_URL="''${KORA_API_URL:-http://glacier:8787}"

      mkdir -p "$STATE_DIR"
      PREV_STATE="$(cat "$STATE_FILE" 2>/dev/null || echo 'unknown')"

      if curl -sf --max-time 2 "$KORA_URL/health" >/dev/null 2>&1; then
        CURR_STATE="online"
      else
        CURR_STATE="offline"
      fi

      if [ "$CURR_STATE" != "$PREV_STATE" ]; then
        printf '%s' "$CURR_STATE" > "$STATE_FILE"
        if [ "$CURR_STATE" = "online" ]; then
          notify-send "⟡ Kora Online" "API disponível em $KORA_URL" \
            --icon "network-transmit-receive" --expire-time 4000
        else
          notify-send "◈ Kora Offline" "API indisponível" \
            --icon "network-error" --expire-time 6000
        fi
      fi
    '';
  };
in
{
  # Arquivo canônico do Caelestia no inspiron.
  # Edite aqui quando quiser ajustar manualmente launcher, apps e comportamento do shell.
  kryonix.shell.caelestia.scheme = {
    name = "kryonix-hud";
    flavour = "hud";
    mode = "dark";
    variant = "vibrant";
    deformScale = 1.14;
    colours = {
      # Chaves de paleta
      primary_paletteKeyColor           = "0099cc"; # hud2
      secondary_paletteKeyColor         = "4d80cc"; # azul médio
      tertiary_paletteKeyColor          = "8b6ee0";
      neutral_paletteKeyColor           = "1e2d3d"; # border
      neutral_variant_paletteKeyColor   = "2a3f50";

      # Background / Surface
      background                = "0a0d12"; # bg0 — espaço profundo
      onBackground              = "e8f4f8"; # fg0
      surfaceDim                = "080b0f";
      surfaceBright             = "1a2232";
      surfaceContainerLowest    = "060810";
      surfaceContainerLow       = "0c1018";
      surfaceContainer          = "0f1419"; # bg1 — painéis
      surfaceContainerHigh      = "151b24"; # bg2
      surfaceContainerHighest   = "1e2432";
      onSurface                 = "e8f4f8";
      surfaceVariant            = "1e2d3d"; # border
      onSurfaceVariant          = "8badbf"; # fg1
      inverseSurface            = "e8f4f8";
      inverseOnSurface          = "0a0d12";
      outline                   = "4a6b7a"; # fg2
      outlineVariant            = "1e2d3d";
      shadow                    = "000000";
      scrim                     = "000000";
      surfaceTint               = "00d4ff"; # hud1

      # Primary — ciano elétrico (#00d4ff)
      primary                   = "00d4ff"; # hud1
      onPrimary                 = "001f26";
      primaryContainer          = "003340";
      onPrimaryContainer        = "a8eeff";
      inversePrimary            = "006880";
      primaryFixed              = "a8eeff";
      primaryFixedDim           = "00d4ff";
      onPrimaryFixed            = "001f26";
      onPrimaryFixedVariant     = "003340";

      # Secondary — azul (#82aaff)
      secondary                 = "82aaff";
      onSecondary               = "001d3d";
      secondaryContainer        = "003566";
      onSecondaryContainer      = "d5e3ff";
      secondaryFixed            = "d5e3ff";
      secondaryFixedDim         = "82aaff";
      onSecondaryFixed          = "001d3d";
      onSecondaryFixedVariant   = "003566";

      # Tertiary — roxo (#b48eff)
      tertiary                  = "b48eff"; # purple
      onTertiary                = "1e0066";
      tertiaryContainer         = "2e1a7a";
      onTertiaryContainer       = "e9dbff";
      tertiaryFixed             = "e9dbff";
      tertiaryFixedDim          = "b48eff";
      onTertiaryFixed           = "1e0066";
      onTertiaryFixedVariant    = "2e1a7a";

      # Estados
      error                     = "ff4455"; # red
      onErrorContainer          = "ffb3bd";
      success                   = "82ddff"; # ciano-azul (sem verde)
      onSuccess                 = "001f30";
      successContainer          = "003348";
      onSuccessContainer        = "b8eeff";

      # Terminal ANSI 16
      term0  = "0a0d12"; # black (bg)
      term1  = "ff4455"; # red
      term2  = "82aaff"; # blue (secondary)
      term3  = "ffcc00"; # yellow
      term4  = "00d4ff"; # blue ciano (hud1)
      term5  = "b48eff"; # magenta (purple)
      term6  = "00ccff"; # cyan
      term7  = "e8f4f8"; # white (fg)
      term8  = "4a6b7a"; # bright black (fg2)
      term10 = "aac4ff"; # bright blue
      term11 = "ffe066"; # bright yellow
      term12 = "66ddff"; # bright cyan
      term13 = "c8aaff"; # bright magenta
      term14 = "88eeff"; # bright cyan 2
      term15 = "ffffff"; # bright white
    };
  };

  kryonix.shell.caelestia.settings = {
    appearance = {
      deformScale = 1.14;
      anim.durations.scale = 1.08;
      font = {
        family = {
          clock = "Rubik";
          material = "Material Symbols Rounded";
          mono = "CaskaydiaCove NF";
          sans = "Rubik";
        };
        size.scale = 0.98;
      };
      transparency = {
        enabled = true;
        base = 0.78;
        layers = 0.42;
      };
    };
    background = {
      enabled = true;
      desktopClock = {
        enabled = true;
        scale = 1.04;
        position = "bottom-right";
        invertColors = false;
        shadow = {
          enabled = true;
          opacity = 0.48;
          blur = 0.62;
        };
        background = {
          enabled = true;
          opacity = 0.16;
          blur = true;
        };
      };
      visualiser = {
        enabled = true;
        blur = true;
        autoHide = true;
        rounding = 1.35;
        spacing = 1.15;
      };
    };

    bar = {
      persistent = true;
      showOnHover = false;
      activeWindow = {
        compact = false;
        inverted = false;
        showOnHover = true;
      };
      clock = {
        background = true;
        showDate = true;
        showIcon = false;
      };
      popouts = {
        activeWindow = true;
        statusIcons = true;
        tray = true;
      };
      status = {
        showAudio = true;
        showBattery = true;
        showBluetooth = true;
        showKbLayout = false;
        showLockStatus = false;
        showMicrophone = false;
        showNetwork = true;
        showWifi = true;
      };
      tray = {
        background = true;
        compact = false;
        recolour = true;
      };
      workspaces = {
        activeIndicator = true;
        activeTrail = true;
        occupiedBg = true;
        perMonitorWorkspaces = true;
        showWindows = true;
        shown = 6;
      };
    };

    border = {
      rounding = 26;
      smoothing = 30;
      thickness = 9;
    };

    dashboard = {
      enabled = true;
      showOnHover = false;
      showMedia = true;
      showPerformance = true;
      showWeather = false;
      mediaUpdateInterval = 700;
      resourceUpdateInterval = 1200;
    };

    general = {
      logo = "caelestia";
      apps = {
        terminal = [ "kryonix-terminal" ];
        explorer = [ "dolphin" ];
        audio = [ "pavucontrol" ];
        playback = [ "mpv" ];
        screenshot = [
          "rag-screenshot"
          "edit-area"
        ];
      };
    };

    launcher = {
      showOnHover = false;
      vimKeybinds = true;
      enableDangerousActions = false;
      maxShown = 9;
      maxWallpapers = 12;
      specialPrefix = "@";
      useFuzzy = {
        apps = false;
        actions = true;
        schemes = true;
        variants = true;
        wallpapers = true;
      };
      favouriteApps = [
        "app.zen_browser.zen"
        "obsidian"
        "code"
        "com.gexperts.Tilix"
        "trae"
        "virt-manager"
        "org.kde.dolphin"
        "org.kde.filelight"
        "com.anydesk.Anydesk"
        "rag-screenshot"
      ];
    };

    notifs = {
      actionOnClick = true;
      clearThreshold = 0.24;
      defaultExpireTimeout = 6000;
      openExpanded = true;
      expire = true;
    };

    paths.wallpaperDir = "~/.local/share/wallpaper";

    services = {
      audioIncrement = 0.05;
      brightnessIncrement = 0.1;
      maxVolume = 1.0;
      smartScheme = false; # paleta HUD fixa — não sobrescrever via wallpaper dinâmico
      useTwelveHourClock = false;
      visualiserBars = 52;
    };

    sidebar.enabled = true;

    utilities = {
      enabled = true;
      maxToasts = 5;
      toasts = {
        audioInputChanged = true;
        audioOutputChanged = true;
        capsLockChanged = false;
        chargingChanged = true;
        configLoaded = true;
        dndChanged = true;
        gameModeChanged = true;
        kbLayoutChanged = true;
        nowPlaying = true;
        numLockChanged = true;
        vpnChanged = true;
      };
    };
  };

  # Kora status — script e monitor de API
  home.packages = [ koraStatusPkg koraMonitorPkg ];

  systemd.user.services.kryonix-kora-monitor = {
    Unit = {
      Description = "Kryonix Kora API monitor (oneshot)";
      After = [ "network.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${koraMonitorPkg}/bin/kryonix-kora-monitor";
    };
  };

  systemd.user.timers.kryonix-kora-monitor = {
    Unit = {
      Description = "Timer para monitor da Kora API";
    };
    Timer = {
      OnBootSec = "30s";
      OnUnitActiveSec = "30s";
      Unit = "kryonix-kora-monitor.service";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
