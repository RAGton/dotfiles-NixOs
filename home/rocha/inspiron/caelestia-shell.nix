{ ... }:
{
  # Arquivo canônico do Caelestia no inspiron.
  # Edite aqui quando quiser ajustar manualmente launcher, apps e comportamento do shell.
  kryonix.shell.caelestia.scheme = {
    name = "kryonix-atlas";
    flavour = "atlas";
    deformScale = 1.14;
    colours = {
      primary_paletteKeyColor = "d2ab72";
      secondary_paletteKeyColor = "8fc3bc";
      tertiary_paletteKeyColor = "aebcff";
      neutral_paletteKeyColor = "101419";
      neutral_variant_paletteKeyColor = "31404a";
      background = "101419";
      onBackground = "edf2f7";
      surfaceDim = "0b0e12";
      surfaceBright = "28303a";
      surfaceContainerLowest = "080a0d";
      surfaceContainerLow = "14191f";
      surfaceContainer = "1a2027";
      surfaceContainerHigh = "232b33";
      surfaceContainerHighest = "2d3640";
      onSurface = "edf2f7";
      surfaceVariant = "31404a";
      onSurfaceVariant = "c0cfda";
      inverseSurface = "edf2f7";
      inverseOnSurface = "171c22";
      outline = "82929e";
      outlineVariant = "44535d";
      shadow = "000000";
      scrim = "000000";
      surfaceTint = "d2ab72";
      primary = "f0c78b";
      onPrimary = "332008";
      primaryContainer = "523916";
      onPrimaryContainer = "ffe0bb";
      inversePrimary = "7d5a28";
      secondary = "9fd8d0";
      onSecondary = "08211d";
      secondaryContainer = "213a36";
      onSecondaryContainer = "bbf4eb";
      tertiary = "c3cbff";
      onTertiary = "1b2555";
      tertiaryContainer = "323d72";
      onTertiaryContainer = "e0e4ff";
      error = "ffb4ab";
      onErrorContainer = "ffdad6";
      success = "9ed8aa";
      onSuccess = "072112";
      successContainer = "214934";
      onSuccessContainer = "bbf5c6";
      primaryFixed = "ffe0bb";
      primaryFixedDim = "f0c78b";
      onPrimaryFixed = "332008";
      onPrimaryFixedVariant = "6a4a1f";
      secondaryFixed = "bbf4eb";
      secondaryFixedDim = "9fd8d0";
      onSecondaryFixed = "08211d";
      onSecondaryFixedVariant = "32514b";
      tertiaryFixed = "e0e4ff";
      tertiaryFixedDim = "c3cbff";
      onTertiaryFixed = "051142";
      onTertiaryFixedVariant = "323d72";
      term0 = "101419";
      term1 = "ef8b8f";
      term2 = "9ed8aa";
      term3 = "f0c78b";
      term4 = "8cbff5";
      term5 = "c4b5ff";
      term6 = "92d8d4";
      term7 = "edf2f7";
      term8 = "596672";
      term10 = "bbf5c6";
      term11 = "ffe3b8";
      term12 = "b9daff";
      term13 = "e2d8ff";
      term14 = "b5f2ee";
      term15 = "ffffff";
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
        enabled = false;
        base = 1.0;
        layers = 1.0;
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
          enabled = false;
          opacity = 0.0;
          blur = 0.0;
        };
        background = {
          enabled = false;
          opacity = 0.0;
          blur = false;
        };
      };
      visualiser = {
        enabled = false;
        blur = false;
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
      showPerformance = false;
      showWeather = false;
      mediaUpdateInterval = 700;
      resourceUpdateInterval = 1200;
    };

    general = {
      logo = "caelestia";
      apps = {
        terminal = [ "warp-terminal" ];
        explorer = [ "dolphin" ];
        audio = [ "pavucontrol" ];
        playback = [ "mpv" ];
      };
    };

    launcher = {
      showOnHover = false;
      vimKeybinds = true;
      enableDangerousActions = false;
      maxShown = 9;
      maxWallpapers = 9;
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
      ];
    };

    notifs = {
      actionOnClick = true;
      clearThreshold = 0.24;
      defaultExpireTimeout = 6000;
      openExpanded = true;
      expire = true;
    };

    paths.wallpaperDir = "~/.local/share/wallpapers";

    services = {
      audioIncrement = 0.05;
      brightnessIncrement = 0.1;
      maxVolume = 1.0;
      smartScheme = true;
      useTwelveHourClock = false;
      visualiserBars = 0;
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
}
