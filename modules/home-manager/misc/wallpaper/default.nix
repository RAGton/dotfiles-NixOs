#+#+#+#+####################################################################
# Home Manager: Wallpaper
# Autor: rag
#
# O que é
# - Define um wallpaper padrão e uma lista (galeria) de wallpapers do usuário.
#
# Por quê
# - Padroniza wallpaper entre ambientes (KDE/Hyprland) de forma declarativa.
#
# Como
# - Expõe `options.wallpaper` e `options.wallpapers`.
# - Publica o wallpaper padrão em `~/.config/wallpaper.png`.
# - Publica a galeria em `~/.local/share/wallpaper/*`.
#
# Riscos
# - `wallpapers` com nomes (basename) repetidos vão colidir no destino.
{ lib, config, ... }:

{
  options.wallpaper = lib.mkOption {
    type = lib.types.path;
    default = ../../../../assets/wallpaper/12.png;
    description = "Caminho do wallpaper padrão.";
  };

  options.wallpapers = lib.mkOption {
    type = lib.types.listOf lib.types.path;
    default = [
      ../../../../assets/wallpaper/01.png
      ../../../../assets/wallpaper/02.png
      ../../../../assets/wallpaper/03.png
      ../../../../assets/wallpaper/04.png
      ../../../../assets/wallpaper/05.png
      ../../../../assets/wallpaper/06.png
      ../../../../assets/wallpaper/07.png
      ../../../../assets/wallpaper/08.png
      ../../../../assets/wallpaper/09.png
      ../../../../assets/wallpaper/10.png
      ../../../../assets/wallpaper/11.png
      ../../../../assets/wallpaper/12.png
    ];
    description = "Lista de wallpapers para instalar em ~/.local/share/wallpaper (galeria).";
  };

  config = {
    home.file.".config/wallpaper.png".source = config.wallpaper;

    # Galeria de wallpapers: adiciona todos os arquivos declarados em `wallpapers`.
    # Obs.: nomes repetidos (mesmo basename) vão colidir.
    xdg.dataFile = lib.listToAttrs (
      map (p: {
        name = "wallpaper/${builtins.baseNameOf p}";
        value.source = p;
      }) config.wallpapers
    );
  };
}
