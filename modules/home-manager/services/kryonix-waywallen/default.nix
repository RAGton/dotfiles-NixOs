{
  config,
  lib,
  osConfig ? null,
  pkgs,
  ...
}:
let
  cfg =
    if osConfig != null then
      osConfig.kryonix.desktop.wallpaper.animated
    else
      {
        enable = false;
        fallback = null;
        path = null;
        wallpaperEngine = {
          enable = false;
        };
      };
  env = if osConfig != null then osConfig.kryonix.desktop.environment else "";
  isHyprland = env == "hyprland";
  fallbackWallpaper =
    if cfg.fallback != null then
      cfg.fallback
    else
      "${pkgs.kryonix-branding}/share/backgrounds/kryonix/kryonix-clean-dark.svg";

  pluginArgs = [
    "--plugin ${pkgs.kryonix-waywallen}/share/waywallen"
  ]
  ++ lib.optional cfg.wallpaperEngine.enable "--plugin ${pkgs.kryonix-open-wallpaper-engine}/share/waywallen";

  waywallenExec = pkgs.writeShellScript "kryonix-waywallen-daemon" ''
    if [ -n "${toString cfg.path}" ] && [ ! -f "${toString cfg.path}" ]; then
      echo "WARN: Animated wallpaper file not found at ${toString cfg.path}."
      echo "WARN: Falling back to static wallpaper."
      # Exiting successfully to avoid crash loop, system will naturally fallback to Plasma's static config
      exit 0
    fi
    exec ${pkgs.kryonix-waywallen}/bin/waywallen \
      --ui ${pkgs.kryonix-waywallen}/bin/waywallen-ui \
      ${lib.concatStringsSep " " pluginArgs}
  '';
in
{
  config = lib.mkIf cfg.enable {
    xdg.dataFile = {
      "kryonix/waywallen/default-wallpaper".source = fallbackWallpaper;
    };

    xdg.desktopEntries.kryonix-waywallen-ui = {
      name = "Waywallen";
      genericName = "Wallpaper Manager";
      comment = "Gerenciador de wallpapers animados do Kryonix";
      exec = "${pkgs.kryonix-waywallen}/bin/waywallen-ui";
      icon = "org.waywallen.waywallen";
      terminal = false;
      categories = [
        "Graphics"
        "Qt"
      ];
    };

    systemd.user.services.kryonix-waywallen = {
      Unit = {
        Description = "Kryonix Waywallen daemon";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = waywallenExec;
        Restart = "on-failure";
        RestartSec = "5s";
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    systemd.user.services.kryonix-waywallen-layer-shell = lib.mkIf isHyprland {
      Unit = {
        Description = "Kryonix Waywallen layer-shell display";
        After = [
          "graphical-session.target"
          "kryonix-waywallen.service"
        ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = "${pkgs.kryonix-waywallen}/bin/waywallen-layer-shell --name kryonix";
        Restart = "on-failure";
        RestartSec = "5s";
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
