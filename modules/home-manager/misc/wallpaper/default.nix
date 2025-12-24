{ lib, pkgs, ... }:
{
  options.wallpaper = lib.mkOption {
    type = lib.types.path;
    default = ./wallpaper.jpg;
    readOnly = true;
    description = "Path to default wallpaper";
  };

  config = {
    # Copy the nixos-artwork wallpapers into the user's wallpapers directory
    home.file.".local/share/wallpapers/nixos-artwork".source = ./nixos-artwork/wallpapers/source;

    # Slideshow helper script
    home.file.".local/bin/nixos-artwork-slideshow".text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      WALLPAPER_DIR="$HOME/.local/share/wallpapers/nixos-artwork"
      INTERVAL="${NIXOS_ARTWORK_SLIDESHOW_INTERVAL:-300}"
      shopt -s nullglob
      files=("$WALLPAPER_DIR"/*)
      if [ ${#files[@]} -eq 0 ]; then
        echo "No wallpapers found in $WALLPAPER_DIR" >&2
        exit 0
      fi
      while true; do
        for f in "${files[@]}"; do
          # set image for every plasma desktop
          qdbus org.kde.plasmashell /PlasmaShell evaluateScript "var d=desktops();for(var i=0;i<d.length;i++){d[i].currentConfigGroup=['Wallpaper','org.kde.image','General'];d[i].writeConfig('Image','file://$f');}"
          sleep "$INTERVAL"
        done
      done
    '';

    # Make the script executable
    home.activation.make-slideshow-exec = {
      text = ''
        chmod +x $HOME/.local/bin/nixos-artwork-slideshow || true
      '';
      # run at activation to ensure executable bit set
      deps = ["${pkgs.coreutils}/bin/chmod"];
    };

    # Autostart entry to run slideshow in background at login
    home.file.".config/autostart/nixos-artwork-slideshow.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Exec=$HOME/.local/bin/nixos-artwork-slideshow &
      Hidden=false
      NoDisplay=false
      X-GNOME-Autostart-enabled=true
      Name=NixOS Artwork Slideshow
      Comment=Cycle wallpapers from nixos-artwork
    '';

    # Recommend qdbus/plasmashell available
    home.packages = with pkgs; [ qdbus plasmashell ];
  };
}
