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
# - SEM painel KDE (panels=[]) — topo reservado para a Kryonix Bar (Rust)
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
    # Identidade global completa: o lookAndFeel é o Global Theme BonaFides
    # (Plasma 6 dark), não mais Breeze Dark — era o Breeze que "dominava" o host.
    # Sobre o lookAndFeel ainda fixamos desktoptheme + colorScheme (aplicados,
    # nesta ordem, DEPOIS do lookAndFeel pelo plasma-manager), porque o default
    # do Global Theme é o esquema CYAN e queremos o azul-preto Kryonix:
    #   - lookAndFeel  → share/plasma/look-and-feel/<Id> (Id == nome da pasta)
    #   - theme        → Plasma desktoptheme (share/plasma/desktoptheme/<id>)
    #   - colorScheme  → "BonaFidesModerateBlueColorScheme" (bg 29,33,47 —
    #                    mais próximo do preto que BlueDark 35,47,65).
    # Assets vêm de `pkgs.bonafides-theme` (instalado em kvantum.nix).
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

      # Wallpaper padrão do Kryonix (assets/wallpaper/12.png — mesmo default do
      # módulo modules/home-manager/misc/wallpaper, que não é importado na sessão
      # KDE; por isso referenciamos o arquivo diretamente).
      wallpaper = if useBlueGlass then blueGlassWallpaper else ../../assets/wallpaper/12.png;
    };

    # NOTA: as decorações Aurorae BonaFides são instaladas pelo pacote
    # (share/aurorae/themes/) e o Global Theme já define a Aurorae
    # "BonaFides-Color-Dark-Aurorae-6" como decoração. NÃO forçamos
    # windowDecorations aqui: a regra global `noborder` (tiling.nix) remove a
    # borda de todas as janelas, então a decoração não é exibida de qualquer
    # forma; deixamos o lookAndFeel cuidar do default e evitamos definição dupla.

    # --- Transparência com blur (Kryonix Glass profundo) ------------------
    # Blur + translucency ligados: painel/menus mostram o wallpaper desfocado
    # atrás, dando profundidade (visual "macOS escuro"). Combinado com o
    # scheme navy de scheme.nix dá o efeito azul/translúcido pedido.
    # Desempenho: aceitável no iGPU Intel do inspiron; se notar lag, basta
    # voltar `blur.enable = false`.
    kwin.effects = {
      blur.enable = true;
      translucency.enable = true;
    };

    # --- PAINEIS Kryonix --------------------------------------------------
    # TOPO  = "Aurora Bar"  → status bar premium (workspaces+título | clock |
    #                          CPU/RAM/rede/áudio/tray). Sempre visível.
    # BAIXO = "Task Dock"   → barra de tarefas (icons-only). Auto-oculta — só
    #                          aparece quando o mouse encosta na borda inferior.
    # Ambos floating + translucent (blur configurado em kwin.effects acima).
    # plasma-manager instala automaticamente `application-title-bar` quando o
    # widget `com.github.antroids.application-title-bar` aparece na lista.
    panels = [
      {
        # ===== PAINEL TOPO: Aurora Bar (status premium) =====================
        location = "top";
        alignment = "center";
        height = 48;
        floating = true;
        lengthMode = "fit";
        hiding = "none";
        opacity = "translucent";
        widgets = [
          # ── Zona esquerda: workspaces + título da janela ─────────────────
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
          "org.kde.plasma.marginsseparator"

          # ── Zona centro: relógio com hora + data ─────────────────────────
          {
            digitalClock = {
              date = {
                enable = true;
                format = "isoDate";
                position = "belowTime";
              };
              time = {
                format = "24h";
                showSeconds = "never";
              };
            };
          }

          "org.kde.plasma.marginsseparator"

          # ── Zona direita: CPU + RAM + rede + áudio + tray ────────────────
          {
            systemMonitor = {
              title = "CPU";
              showTitle = false;
              showLegend = false;
              displayStyle = "org.kde.ksysguard.textonly";
              totalSensors = [ "cpu/all/usage" ];
              sensors = [
                {
                  name = "cpu/all/usage";
                  color = "56,189,248";
                  label = "CPU";
                }
              ];
              textOnlySensors = [
                "cpu/all/averageFrequency"
                "cpu/all/averageTemperature"
              ];
            };
          }
          {
            systemMonitor = {
              title = "RAM";
              showTitle = false;
              showLegend = false;
              displayStyle = "org.kde.ksysguard.textonly";
              totalSensors = [ "memory/physical/usedPercent" ];
              sensors = [
                {
                  name = "memory/physical/usedPercent";
                  color = "56,189,248";
                  label = "RAM";
                }
              ];
              textOnlySensors = [
                "memory/physical/used"
                "memory/physical/total"
              ];
            };
          }
          "org.kde.plasma.systemtray"
        ];
      }

      {
        # ===== PAINEL INFERIOR: Task Dock (icons-only, auto-hide) ============
        # Aparece quando o mouse encosta na borda inferior; some sozinho.
        # Mostra apenas ícones de janelas abertas (icons-only-task-manager).
        # 56px de altura dá um dock confortável; floating + translucent batem
        # com o painel topo. lengthMode=fit segue a quantidade de ícones.
        location = "bottom";
        alignment = "center";
        height = 56;
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
      # --- Dolphin otimizado ---------------------------------------------
      # Previews habilitados por padrão; reforçamos caminho completo, info de
      # espaço e navegação em arquivos compactados. (Split view é ação por-janela
      # em Ctrl+F3, não estado persistente.)
      dolphinrc.General = {
        ShowFullPath = true;
        ShowSpaceInfo = true;
        BrowseThroughArchives = true;
      };

      # --- Kryonix Glass: accent azul Kryonix (#38BDF8) ------------------
      # Coerente com os gauges da barra (56,189,248), o launcher fuzzel e o
      # esquema "Kryonix Dark". Era #89B4FA (catppuccin) — desalinhado do resto
      # do desktop. O blur é configurado em kwin.effects acima (evita dupla def).
      kdeglobals.General = {
        accentColorFromWallpaper = false;
        AccentColor = "56,189,248";
      };

      # --- Sessão limpa (sem restaurar janelas da última sessão) ----------
      # Default do Plasma 6 tenta restaurar Firefox/VSCode/Dolphin do logout
      # anterior — quebra a impressão de "abre limpo". emptySession = sempre
      # começar zerado. confirmLogout=false porque o atalho de reboot (Meta+
      # Ctrl+Esc) já vai por LogoutPrompt.promptReboot (keybinds.nix).
      ksmserverrc.General = {
        loginMode = "emptySession";
        confirmLogout = false;
      };
    };
  };

  # NOTA: não rodamos plasma-apply-lookandfeel via home.activation. O próprio
  # plasma-manager (programs.plasma) já aplica o lookAndFeel acima no activation
  # do módulo. A activation extra usava ID errado ("BonaFides-Color-Plasma" — o
  # ID real do Global Theme é "BonaFides-Dark-Color-Global-6", definido em
  # workspace.lookAndFeel acima) e só gerava warning no journal sem efeito útil.
}
