# =============================================================================
# desktop/kde/theme.nix — Camada visual do KDE (Home Manager)
#
# Arquitetura visual:
# - Global Theme: BonaFides Dark (lookAndFeel "BonaFides-Dark-Color-Global-6")
# - Desktop Theme: BonaFides-Color-Plasma (FrameSVG profissional completo)
#   ou kryonix-blue-glass (herda SVGs do BonaFides via fallback, aplica paleta
#   Kryonix navy: 11,18,32 / accent 59,130,246 via ColorScheme-Background)
# - Blur + transparência (KWin effects)
# - Cursor Nordzy-cursors, tamanho 24
# - Top bar: 28px, fixa, full-width, sem pager
# - Dock: 40px, flutuante, auto-hide, icons-only
# - Dolphin otimizado
# =============================================================================
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

  home.packages = [
    pkgs.whitesur-kde
    pkgs.whitesur-icon-theme
  ];

  programs.plasma = {
    # ATENÇÃO: overrideConfig força a reescrita do plasma-manager. Se causar problemas com applets, remova.
    overrideConfig = true;

    # --- Tema WhiteSur-KDE (macOS/Hyprland Glass) ----------------------------
    workspace = {
      lookAndFeel = "com.github.vinceliuice.WhiteSur-dark";
      theme = "WhiteSur-dark";
      colorScheme = "WhiteSurDark";
      iconTheme = "WhiteSur-dark";
      cursor = {
        theme = "Nordzy-cursors";
        size = 24;
      };
      wallpaperSlideShow = {
        path = "${pkgs.kryonix-wallpapers}/share/wallpapers/kryonix-aurora";
        interval = 300;
      };
    };

    # --- Blur (Kryonix Glass profundo) ------------------------------------

    configFile.kwinrc = {
      Plugins.desktopchangeosdEnabled = true;
      "Script-desktopchangeosd" = {
        PopupHideDelay = 600;
        TextOnly = false;
      };
      "Effect-slide" = {
        Duration = 200;
        HorizontalGap = 30;
        VerticalGap = 20;
      };
    };

    # --- PAINEL Kryonix (macOS/Niri 3-Island Topology) -------------------
    # Três ilhas flutuantes superiores para launcher, relógio e tray.
    # FALLBACK DOCUMENTADO: Se o Plasma 6 ficar instável com 3 painéis flutuantes reais
    # (ex: sobreposição ou crash do KWin), reverter para 1 único painel transparente com
    # alignment=center, lengthMode=fill, e usar org.kde.plasma.panelspacer entre os blocos.
    panels = [
      {
        location = "top";
        alignment = "center";
        height = 36;
        floating = true;
        lengthMode = "fill";
        hiding = "none";
        opacity = "translucent";
        widgets = [
          {
            name = "org.latgardi.darwinmenu";
            config = {
              General = {
                icon = "${pkgs.kryonix-branding}/share/icons/hicolor/scalable/apps/kryonix-logo.svg";
              };
            };
          }
          {
            name = "org.kde.plasma.pager";
            config = {
              General = {
                displayedText = "Number";
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

          "org.kde.plasma.panelspacer"

          {
            digitalClock = {
              date = {
                enable = true;
                format = "shortDate";
                position = "besideTime";
              };
              time = {
                format = "24h";
                showSeconds = "never";
              };
            };
          }

          "org.kde.plasma.panelspacer"

          {
            name = "org.kde.plasma.systemmonitor.cpucore";
            config = {
              Appearance = {
                chartFace = "org.kde.ksysguard.linechart";
              };
            };
          }
          {
            name = "org.kde.plasma.systemmonitor.memory";
            config = {
              Appearance = {
                chartFace = "org.kde.ksysguard.linechart";
              };
            };
          }
          "org.kde.plasma.systemtray"
        ];
      }
      {
        location = "bottom";
        alignment = "center";
        height = 56;
        floating = true;
        lengthMode = "fit";
        hiding = "windowscover";
        opacity = "translucent";
        widgets = [
          {
            iconTasks = {
              launchers = [
                "applications:org.kde.dolphin.desktop"
                "applications:code.desktop"
                "applications:dev.warp.Warp.desktop"
                "applications:google-chrome.desktop"
                "applications:microsoft-edge.desktop"
                "applications:steam.desktop"
                "applications:obsidian.desktop"
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
