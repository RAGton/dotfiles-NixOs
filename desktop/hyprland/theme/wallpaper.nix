{ pkgs, ... }:
{
  # Script de troca de wallpaper via Caelestia (gerencia transição + esquema de cores)
  home.file.".local/bin/kryonix-wallpaper" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Uso: kryonix-wallpaper [caminho/para/arte.png]
      #      kryonix-wallpaper --random
      #      kryonix-wallpaper --next

      WALL_DIR="/etc/kryonix/assets/wallpaper"

      set_wall() {
        local img="$1"
        [ -f "$img" ] || { echo "Arquivo não encontrado: $img"; exit 1; }
        caelestia wallpaper -f "$img"
        notify-send "Kryonix Wallpaper" "$(basename "$img")" \
          --icon "image-x-generic" --expire-time 2000
      }

      case "$1" in
        --random|--next)
          caelestia wallpaper -r "$WALL_DIR"
          ;;
        "")
          caelestia wallpaper -r "$WALL_DIR"
          ;;
        *)
          set_wall "$1"
          ;;
      esac
    '';
  };
}
