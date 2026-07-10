{ config, lib, pkgs, ... }:

let
  cfg = config.kryonix.desktop.kde.multimonitor;
in {
  options.kryonix.desktop.kde.multimonitor = {
    enable = lib.mkEnableOption "Kryonix Multi-Monitor Support (idempotent fallback)";
    wallpapers = {
      primary = lib.mkOption {
        type = lib.types.str;
        default = "kryonix-aurora";
        description = "Name of the wallpaper directory/file for the primary monitor.";
      };
      secondary = lib.mkOption {
        type = lib.types.str;
        default = "kryonix-aurora";
        description = "Name of the wallpaper directory/file for secondary monitors.";
      };
      fallback = lib.mkOption {
        type = lib.types.str;
        default = "kryonix-aurora";
        description = "Fallback wallpaper for any other screens.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.kryonix-plasma-multiscreen = {
      Unit = {
        Description = "Apply Kryonix Wallpapers to all monitors";
        After = [ "plasma-plasmashell.service" ];
        Requires = [ "plasma-plasmashell.service" ];
      };
      Install = {
        WantedBy = [ "plasma-workspace.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
        ExecStart = let
          script = pkgs.writeText "apply-multiscreen-wallpapers.js" ''
            let allDesktops = desktops();
            for (let i = 0; i < allDesktops.length; i++) {
                let d = allDesktops[i];
                d.wallpaperPlugin = "org.kde.slideshow";
                d.currentConfigGroup = ["Wallpaper", "org.kde.slideshow", "General"];
                
                // Aplicamos para todas as telas (primária ou secundária) o slideshow Kryonix.
                // O path é baseado no pacote atual de wallpapers do sistema.
                let path = "${pkgs.kryonix-wallpapers}/share/wallpapers/${cfg.wallpapers.fallback}";
                
                // É possível especializar futuramente usando d.screen == 0 vs d.screen > 0
                
                d.writeConfig("SlidePaths", path);
                d.writeConfig("SlideInterval", "300");
                d.writeConfig("FillMode", "2"); // Stretch or scaled
            }
          '';
        in "${pkgs.bash}/bin/bash -c \"${pkgs.kdePackages.qttools}/bin/qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \\\"$(${pkgs.coreutils}/bin/cat ${script})\\\"\"";
        Restart = "on-failure";
        TimeoutSec = "20";
      };
    };
  };
}
