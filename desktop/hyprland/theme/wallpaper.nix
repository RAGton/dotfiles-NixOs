{ pkgs, ... }:
{
  home.packages = [
    pkgs.awww
    pkgs.matugen
  ];

  # Script de troca de wallpaper com transição sci-fi
  home.file.".local/bin/kryonix-wallpaper" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Uso: kryonix-wallpaper [caminho/para/arte.png]
      #      kryonix-wallpaper --random
      #      kryonix-wallpaper --next

      WALL_DIR="/etc/kryonix/files/wallpaper"
      STATE_FILE="$HOME/.local/state/kryonix/wallpaper-current"

      mkdir -p "$(dirname "$STATE_FILE")"

      set_wall() {
        local img="$1"
        [ -f "$img" ] || { echo "Arquivo não encontrado: $img"; exit 1; }

        # Transição: wipe da esquerda para direita — estilo scan de HUD
        awww img "$img" \
          --transition-type wipe \
          --transition-angle 30 \
          --transition-duration 1.2 \
          --transition-fps 60 \
          --transition-bezier 0.4,0.0,0.2,1.0

        echo "$img" > "$STATE_FILE"

        # Gerar paleta de cores a partir da arte
        matugen image "$img" --mode dark 2>/dev/null &

        notify-send "🖼 Kryonix Wallpaper" "$(basename "$img")" \
          --icon "image-x-generic" --expire-time 2000
      }

      case "$1" in
        --random)
          img=$(find "$WALL_DIR" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.webp' \) | shuf -n1)
          set_wall "$img"
          ;;
        --next)
          current=$(cat "$STATE_FILE" 2>/dev/null)
          imgs=( $(find "$WALL_DIR" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.webp' \) | sort) )
          idx=0
          for i in "''${!imgs[@]}"; do
            [ "''${imgs[$i]}" = "$current" ] && idx=$(( (i+1) % ''${#imgs[@]} ))
          done
          set_wall "''${imgs[$idx]}"
          ;;
        "")
          # Sem argumento — restaura o último ou escolhe aleatório
          current=$(cat "$STATE_FILE" 2>/dev/null)
          [ -f "$current" ] && set_wall "$current" || $0 --random
          ;;
        *)
          set_wall "$1"
          ;;
      esac
    '';
  };

  # Inicializar awww e restaurar wallpaper na sessão
  wayland.windowManager.hyprland.settings.exec-once = [
    "${pkgs.awww}/bin/awww-daemon --format xrgb"
    "sleep 0.5 && ~/.local/bin/kryonix-wallpaper"
  ];
}
