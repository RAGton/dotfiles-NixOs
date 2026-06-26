{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = osConfig.kryonix.desktop.wallpaper.dynamic;
  env = osConfig.kryonix.desktop.environment;
  isHyprland = env == "hyprland";
  fallbackWallpaper =
    if cfg.defaultWallpaper != null then
      cfg.defaultWallpaper
    else
      "${pkgs.kryonix-branding}/share/backgrounds/kryonix/kryonix-clean-dark.svg";
  brandingWallpapers = {
    "kryonix-blue-glass-dark.svg" =
      "${pkgs.kryonix-branding}/share/backgrounds/kryonix/kryonix-blue-glass-dark.svg";
    "kryonix-blue-glass-light.svg" =
      "${pkgs.kryonix-branding}/share/backgrounds/kryonix/kryonix-blue-glass-light.svg";
    "kryonix-clean-dark.svg" =
      "${pkgs.kryonix-branding}/share/backgrounds/kryonix/kryonix-clean-dark.svg";
    "kryonix-clean-light.svg" =
      "${pkgs.kryonix-branding}/share/backgrounds/kryonix/kryonix-clean-light.svg";
  };
  pluginArgs = [
    "--plugin ${pkgs.kryonix-waywallen}/share/waywallen"
  ]
  ++ lib.optional cfg.wallpaperEngine.enable "--plugin ${pkgs.kryonix-open-wallpaper-engine}/share/waywallen";
  waywallenExec = pkgs.writeShellScript "kryonix-waywallen-daemon" ''
    exec ${pkgs.kryonix-waywallen}/bin/waywallen \
      --ui ${pkgs.kryonix-waywallen}/bin/waywallen-ui \
      ${lib.concatStringsSep " " pluginArgs}
  '';
in
{
  config = lib.mkIf cfg.enable {
    xdg.dataFile = {
      "kryonix/waywallen/default-wallpaper".source = fallbackWallpaper;
    }
    // lib.mapAttrs' (name: source: {
      name = "kryonix/waywallen/wallpapers/${name}";
      value.source = source;
    }) brandingWallpapers;

    xdg.desktopEntries.kryonix-waywallen-ui = {
      name = "Waywallen";
      genericName = "Wallpaper Manager";
      comment = "Gerenciador de wallpapers dinamicos do Kryonix";
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
