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

  programs.plasma = {
    # ATENÇÃO: overrideConfig força a reescrita do plasma-manager. Se causar problemas com applets, remova.
    overrideConfig = true;

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

    # --- Blur (Kryonix Glass profundo) ------------------------------------
    kwin.effects = {
      blur.enable = true;
      translucency.enable = true; # Restaurado para garantir barra de título glass
    };

    # --- PAINEL Kryonix (macOS-style Unified Top Bar) -------------------
    # Layout unificado com altura reduzida, ocupando a barra superior inteira.
    panels = [
      # 1. Top Bar
      {
        location = "top";
        alignment = "center";
        height = 28;
        floating = false; # Barra fixa completa na tela inteira
        lengthMode = "fill";
        hiding = "none";
        opacity = "translucent";
        widgets = [
          # --- Left ---
          "org.kde.plasma.marginsseparator"
          "org.kde.plasma.pager"
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
          # --- Right ---
          "org.kde.plasma.systemmonitor.cpucore"
          "org.kde.plasma.systemmonitor.memory"
          "org.kde.plasma.systemtray"
        ];
      }

      # 4. Dock Inferior (Auto-hide)
      {
        # ===== PAINEL INFERIOR: Task Dock (glass auto-hide) ==================
        location = "bottom";
        alignment = "center";
        height = 40;
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
                "applications:google-chrome.desktop"
                "applications:microsoft-edge.desktop"
                "applications:steam.desktop"
                "applications:antigravity.desktop"
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
