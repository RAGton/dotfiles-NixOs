# =============================================================================
# desktop/kde/wallpaper.nix — Seleção declarativa de wallpaper para KDE Plasma
#
# O que é:
# - Permite trocar o wallpaper do KDE Plasma de forma declarativa via
#   programs.plasma.workspace.wallpaper (plasma-manager).
# - Integra o pack kryonix-wallpapers (packages/kryonix-wallpapers.nix).
#
# Como usar (em hosts/inspiron/default.nix ou home):
#   imports = [ ../../desktop/kde/wallpaper.nix ];
#   # wallpaper padrão do pack anime (branded):
#   programs.plasma.workspace.wallpaper =
#     "${pkgs.kryonix-wallpapers}/share/wallpapers/kryonix-aurora/kryonix-anime-city-01.png";
#
# Wallpapers disponíveis no pack kryonix-aurora:
#   SPACE/ABSTRACT (sem logo):
#     kryonix-aurora-01.png  — Nebulosa espiral azul
#     kryonix-aurora-02.png  — Grid hexagonal tech
#     kryonix-aurora-03.png  — Aurora boreal + montanhas
#     kryonix-aurora-04.png  — Ondas fluidas azuis
#     kryonix-aurora-05.png  — Glow minimalista (ideal painel transparente)
#     kryonix-aurora-06.png  — Galáxia espiral
#     kryonix-aurora-07.png  — Rede de partículas
#
#   ANIME (com logo águia + "KRYONIX"):
#     kryonix-anime-01.png          — Cidade cyberpunk verde noturna
#     kryonix-anime-02.png          — Personagem sob lua cheia
#     kryonix-anime-city-01.png     — Cidade futurista verde pôr-do-sol ★ recomendado
#     kryonix-anime-char-01.png     — Guerreiro + cidade mágica verde
#     kryonix-anime-landscape-01.png — Ilha flutuante Ghibli
#     kryonix-anime-night-city.png  — Rua chuvosa neon verde
#     kryonix-anime-forest-mech.png — Mech na floresta bioluminescente
#
# Slideshow KDE (trocar a cada 5 min):
#   xdg.configFile."plasma-org.kde.plasma.desktop-appletsrc" pode ser usado
#   para configurar slideshow — ver pendências em docs/desktop/KRYONIX_WALLPAPERS.md
# =============================================================================
{ pkgs, ... }:
{
  home.packages = [ pkgs.kryonix-wallpapers ];

  # Wallpaper padrão: anime cidade futurista verde com logo Kryonix.
  # Troque o basename para qualquer outro wallpaper listado acima.
  programs.plasma.workspace.wallpaper =
    "${pkgs.kryonix-wallpapers}/share/wallpapers/kryonix-aurora/kryonix-anime-city-01.png";
}
