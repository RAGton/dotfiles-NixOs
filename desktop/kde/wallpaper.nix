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
#   # wallpaper padrão oficial do pack Kryonix:
#   programs.plasma.workspace.wallpaper =
#     "${pkgs.kryonix-wallpapers}/share/wallpapers/kryonix-aurora/kryonix-dark-4k.png";
#
# Wallpapers oficiais disponíveis no pack kryonix-aurora:
#   kryonix-dark-4k.png — versão dark oficial com Águia K com Escudo
#   kryonix-aurora.png  — versão aurora oficial com Águia K com Escudo
#
# Slideshow KDE (trocar a cada 5 min):
#   xdg.configFile."plasma-org.kde.plasma.desktop-appletsrc" pode ser usado
#   para configurar slideshow — ver pendências em docs/desktop/KRYONIX_WALLPAPERS.md
# =============================================================================
{ pkgs, ... }:
{
  home.packages = [ pkgs.kryonix-wallpapers ];

  # Wallpaper padrão oficial derivado da Águia K com Escudo.
  programs.plasma.workspace.wallpaper = "${pkgs.kryonix-wallpapers}/share/wallpapers/kryonix-aurora/kryonix-dark-4k.png";
}
