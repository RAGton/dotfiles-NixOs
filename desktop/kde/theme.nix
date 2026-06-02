# =============================================================================
# desktop/kde/theme.nix — Camada visual moderna do KDE (Home Manager)
#
# Estética padrão do ambiente principal:
# - Tema global Breeze Dark (consistente em Qt/KDE)
# - Blur + transparência (efeitos do KWin)
# - Animações mantidas (não zeramos AnimationDurationFactor)
# - Cursor Nordzy-cursors (X11, GTK e Wayland), tamanho 24
# - Painel superior minimalista (menu, tarefas em ícones, systray, relógio)
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
    # Base global: mantemos o lookAndFeel Breeze Dark como esqueleto estável do
    # Plasma 6 e sobrepomos a identidade BonaFides via desktoptheme + colorScheme
    # (aplicados, nesta ordem, DEPOIS do lookAndFeel pelo plasma-manager).
    #   - theme        → Plasma desktoptheme (share/plasma/desktoptheme/<id>)
    #   - colorScheme  → base do .colors (share/color-schemes/<base>.colors)
    # Assets vêm de `pkgs.bonafides-theme` (instalado em kvantum.nix).
    workspace = {
      lookAndFeel = "org.kde.breezedark.desktop";
      theme = "BonaFides-Color-Plasma";
      colorScheme = "BonaFidesBlueDarkColorscheme";
      iconTheme = "breeze-dark";
      cursor = {
        theme = "Nordzy-cursors";
        size = 24;
      };

      # Wallpaper padrão do Kryonix (files/wallpaper/12.png — mesmo default do
      # módulo modules/home-manager/misc/wallpaper, que não é importado na sessão
      # KDE; por isso referenciamos o arquivo diretamente).
      wallpaper = ../../files/wallpaper/12.png;
    };

    # NOTA: as decorações Aurorae BonaFides são instaladas pelo pacote
    # (share/aurorae/themes/), mas NÃO forçamos windowDecorations aqui: a regra
    # global `noborder` (tiling.nix) remove a borda de todas as janelas, então a
    # decoração não seria exibida. Forçá-la junto do lookAndFeel Breeze ainda
    # gera o aviso "lookAndFeel override" do plasma-manager sem ganho visual.

    # --- Blur profundo + transparência (Kryonix Glass) --------------------
    kwin.effects = {
      blur = {
        enable = true;
        strength = 12; # 1–15: blur reforçado atrás de painéis/menus translúcidos
        noiseStrength = 0;
      };
      translucency.enable = true;
    };

    # --- Painel superior minimalista, flutuante e translúcido (Glass) -----
    panels = [
      {
        location = "top";
        height = 32;
        floating = true; # barra "glass" destacada da borda
        opacity = "translucent"; # transparência profunda (com blur do KWin atrás)
        widgets = [
          "org.kde.plasma.kickoff"
          "org.kde.plasma.icontasks"
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
