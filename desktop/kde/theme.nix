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
    theme = {
      name = "Breeze-Dark";
      package = pkgs.kdePackages.breeze-gtk;
    };
    iconTheme = {
      name = "breeze-dark";
      package = pkgs.kdePackages.breeze-icons;
    };
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

    # --- Blur profundo + transparência (Kryonix Glass) --------------------
    kwin.effects = {
      blur = {
        enable = true;
        strength = 12; # 1–15: blur reforçado atrás de painéis/menus translúcidos
        noiseStrength = 0;
      };
      translucency.enable = true;
    };

    # --- PAINEL FALLBACK (Fase 1): Ilha minimalista até a Kryonix Bar estar pronta ---
    # Em vez de panels = [ ], restauramos um painel 'Floating Island' para manter
    # a usabilidade mínima (Workspaces, Relógio, Tray).
    panels = [
      {
        location = "top";
        alignment = "center";
        height = 38;
        floating = true;
        lengthMode = "fit"; # Estilo ilha (não ocupa 100% da largura)
        hiding = "none";
        opacity = "translucent";
        widgets = [
          "org.kde.plasma.kickoff"
          "org.kde.plasma.pager"
          "org.kde.plasma.marginsseparator"
          "org.kde.plasma.systemtray"
          "org.kde.plasma.digitalclock"
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

      # --- Kryonix Glass: accent azul coerente com o Kvantum -------------
      # (catppuccin mocha blue #89B4FA). O blur é configurado via
      # kwin.effects.blur.strength acima, não aqui (evita definição dupla).
      kdeglobals.General = {
        accentColorFromWallpaper = false;
        AccentColor = "137,180,250";
      };
    };
  };
}
