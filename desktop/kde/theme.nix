# =============================================================================
# desktop/kde/theme.nix — Camada visual moderna do KDE (Home Manager)
#
# Estética padrão do ambiente principal:
# - Global Theme BonaFides Dark (lookAndFeel "BonaFides-Dark-Color-Global-6")
#   + desktoptheme "BonaFides-Color-Plasma" + colorScheme "ModerateBlue"
#   (backgrounds azul-preto profundo: 29,33,47 — mais escuro que BlueDark).
# - Blur + transparência (efeitos do KWin)
# - Animações mantidas (não zeramos AnimationDurationFactor)
# - Cursor Nordzy-cursors (X11, GTK e Wayland), tamanho 24
# - Painel topo: "Aurora Bar" — glass compacto (32px), floating pill
# - Painel baixo: "Task Dock" — icons-only auto-hide (44px), floating glass
# - Dolphin otimizado (caminho completo, navegação em arquivos)
# =============================================================================
{
  osConfig,
  pkgs,
  ...
}:
let
  preset = osConfig.kryonix.desktop.kde.theme.preset or "bonafides";
  useBlueGlassDark = preset == "kryonix-blue-glass-dark";
  useBlueGlassLight = preset == "kryonix-blue-glass-light";
  useBlueGlass = useBlueGlassDark || useBlueGlassLight;
  blueGlassWallpaper =
    if useBlueGlassLight then
      "${pkgs.kryonix-branding}/share/backgrounds/kryonix/kryonix-blue-glass-light.svg"
    else
      "${pkgs.kryonix-branding}/share/backgrounds/kryonix/kryonix-blue-glass-dark.svg";
in
{
  # --- Cursor Nordzy (X11 / GTK / Wayland) ---------------------------------
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.nordzy-cursor-theme;
    name = "Nordzy-cursors";
    size = 24;
  };

  # --- GTK escuro coerente (apps GTK sob o Plasma) -------------------------
  # Também provê o conteúdo de gtk-3.0/settings.ini esperado pelos perfis que
  # marcam `.force = true` (ex.: users/shared/dev-workstation.nix), antes provido
  # pelo stack GTK do Hyprland.
  gtk = {
    enable = true;
    gtk2.force = true;
    theme = {
      name = "Breeze-Dark";
      package = pkgs.kdePackages.breeze-gtk;
    };
    iconTheme = {
      name = "breeze-dark";
      package = pkgs.kdePackages.breeze-icons;
    };
  };

  xdg.configFile = {
    "gtk-3.0/settings.ini".force = true;
    "gtk-4.0/settings.ini".force = true;
  };

  programs.plasma = {
    # --- Tema BonaFides (Dark/Azul-Preto/Glass) ----------------------------
    workspace = {
      lookAndFeel = "BonaFides-Dark-Color-Global-6";
      theme = if useBlueGlass then "kryonix-blue-glass" else "BonaFides-Color-Plasma";
      colorScheme =
        if useBlueGlassDark then
          "KryonixBlueGlassDark"
        else if useBlueGlassLight then
          "KryonixBlueGlassLight"
        else
          "BonaFidesModerateBlueColorScheme";
      iconTheme = "breeze-dark";
      cursor = {
        theme = "Nordzy-cursors";
        size = 24;
      };
      wallpaper = if useBlueGlass then blueGlassWallpaper else ../../assets/wallpaper/12.png;
    };

    # --- Transparência com blur (Kryonix Glass profundo) ------------------
    kwin.effects = {
      blur.enable = true;
      translucency.enable = true;
    };

    # --- PAINEL Kryonix (macOS-style Unified Top Bar) -------------------
    # Layout unificado com altura reduzida, ocupando a barra superior inteira.
    panels = [
      # 1. Top Bar
      {
        location = "top";
        alignment = "left";
        height = 28;
        floating = false;
        lengthMode = "fill";
        hiding = "none";
        opacity = "translucent";
        widgets = [
          # --- Left ---
          {
            pager = {
              general = {
                displayedText = "desktopNumber";
                showWindowOutlines = false;
              };
            };
          }
          {
            applicationTitleBar = {
              windowTitle.source = "appName";
              layout = {
                elements = [ "windowTitle" ];
                horizontalAlignment = "left";
                fillFreeSpace = false;
              };
              overrideForMaximized.enable = false;
              titleReplacements = [ ];
            };
          }
          # --- Center ---
          "org.kde.plasma.panelspacer"
          {
            digitalClock = {
              date = {
                enable = true;
                format = "isoDate";
                position = "besideTime";
              };
              time = {
                format = "24h";
                showSeconds = "never";
              };
            };
          }
          "org.kde.plasma.panelspacer"
          # --- Right ---
          "org.kde.plasma.systemtray"
        ];
      }

      # 4. Dock Inferior (Auto-hide)
      {
        # ===== PAINEL INFERIOR: Task Dock (glass auto-hide) ==================
        location = "bottom";
        alignment = "center";
        height = 38;
        floating = true;
        lengthMode = "fit";
        hiding = "autohide";
        opacity = "translucent";
        widgets = [
          {
            iconTasks = {
              launchers = [
                "applications:dolphin.desktop"
                "applications:code-insiders.desktop"
                "applications:warp-terminal.desktop"
              ];
              appearance = {
                showTooltips = true;
                indicateAudioStreams = true;
                fill = false;
              };
              behavior = {
                grouping = {
                  method = "byProgramName";
                  clickAction = "cycle";
                };
                sortingMethod = "manually";
                showTasks = {
                  onlyInCurrentScreen = false;
                  onlyInCurrentDesktop = false;
                  onlyInCurrentActivity = true;
                  onlyMinimized = false;
                };
                newTasksAppearOn = "right";
              };
            };
          }
        ];
      }
    ];

    configFile = {
      # --- Dolphin otimizado -----------------------------------------------
      dolphinrc.General = {
        ShowFullPath = true;
        ShowSpaceInfo = true;
        BrowseThroughArchives = true;
      };

      # --- Kryonix Glass: accent azul Kryonix (#38BDF8) --------------------
      kdeglobals.General = {
        accentColorFromWallpaper = false;
        AccentColor = "56,189,248";
      };

      # --- Sessão limpa (sem restaurar janelas da última sessão) ------------
      ksmserverrc.General = {
        loginMode = "emptySession";
        confirmLogout = false;
      };
    };
  };
}
