# =============================================================================
# desktop/kde/theme.nix — Camada visual moderna do KDE (Home Manager)
#
# Estética padrão do ambiente principal:
# - Global Theme BonaFides Dark (lookAndFeel "BonaFides-Dark-Color-Global-6")
#   + desktoptheme/colorScheme azul Kryonix (override do default cyan)
# - Blur + transparência (efeitos do KWin)
# - Animações mantidas (não zeramos AnimationDurationFactor)
# - Cursor Nordzy-cursors (X11, GTK e Wayland), tamanho 24
# - SEM painel KDE (panels=[]) — topo reservado para a Kryonix Bar (Rust)
# - Dolphin otimizado (caminho completo, navegação em arquivos)
# =============================================================================
{ pkgs, ... }:
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
    # --- Tema BonaFides (Dark/Azul/Glass) ----------------------------------
    # Identidade global completa: o lookAndFeel é o Global Theme BonaFides
    # (Plasma 6 dark), não mais Breeze Dark — era o Breeze que "dominava" o host.
    # Sobre o lookAndFeel ainda fixamos desktoptheme + colorScheme (aplicados,
    # nesta ordem, DEPOIS do lookAndFeel pelo plasma-manager), porque o default
    # do Global Theme é o esquema CYAN e queremos o azul Kryonix:
    #   - lookAndFeel  → share/plasma/look-and-feel/<Id> (Id == nome da pasta)
    #   - theme        → Plasma desktoptheme (share/plasma/desktoptheme/<id>)
    #   - colorScheme  → base do .colors (share/color-schemes/<base>.colors)
    # Assets vêm de `pkgs.bonafides-theme` (instalado em kvantum.nix).
    workspace = {
      lookAndFeel = "BonaFides-Dark-Color-Global-6";
      theme = "BonaFides-Color-Plasma";
      colorScheme = "BonaFidesBlueDarkColorscheme";
      iconTheme = "breeze-dark";
      cursor = {
        theme = "Nordzy-cursors";
        size = 24;
      };

      # Wallpaper padrão do Kryonix (assets/wallpaper/12.png — mesmo default do
      # módulo modules/home-manager/misc/wallpaper, que não é importado na sessão
      # KDE; por isso referenciamos o arquivo diretamente).
      wallpaper = ../../assets/wallpaper/12.png;
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

    # --- PAINEL Kryonix Aurora Bar (PR 8C) ------------------------------------
    # Floating island premium: 3 zonas (workspaces+título | clock | métricas+tray)
    # Translucency sem blur (já configurado acima).
    # plasma-manager instala automaticamente `application-title-bar` quando o
    # widget `com.github.antroids.application-title-bar` aparece na lista.
    panels = [
      {
        location = "top";
        alignment = "center";
        height = 40;
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
          "org.kde.plasma.networkmanagement"
          "org.kde.plasma.volume"
          "org.kde.plasma.systemtray"
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
    };
  };

  # NOTA: não rodamos plasma-apply-lookandfeel via home.activation. O próprio
  # plasma-manager (programs.plasma) já aplica o lookAndFeel acima no activation
  # do módulo. A activation extra usava ID errado ("BonaFides-Color-Plasma" — o
  # ID real do Global Theme é "BonaFides-Dark-Color-Global-6", definido em
  # workspace.lookAndFeel acima) e só gerava warning no journal sem efeito útil.
}
