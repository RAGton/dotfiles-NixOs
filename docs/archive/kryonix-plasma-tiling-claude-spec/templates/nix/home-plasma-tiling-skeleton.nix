# Skeleton: Home Manager Plasma/KWin tiling config
{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.kryonix.home.desktop.plasma.tiling;
  reloadKWin = ''
    if command -v qdbus6 >/dev/null 2>&1; then
      qdbus6 org.kde.KWin /KWin reconfigure || true
    elif command -v qdbus >/dev/null 2>&1; then
      qdbus org.kde.KWin /KWin reconfigure || true
    fi
  '';
in
{
  options.kryonix.home.desktop.plasma.tiling = {
    enable = lib.mkEnableOption "Declarative KWin tiling configuration";
    pluginId = lib.mkOption {
      type = lib.types.str;
      default = "polonium";
    };
    forceKwinrc = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Force replace kwinrc. Use carefully because Plasma GUI also writes this file.";
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."kwinrc" = {
      force = cfg.forceKwinrc;
      text = ''
        [Plugins]
        ${cfg.pluginId}Enabled=true

        [Windows]
        ElectricBorders=0
      '';
      onChange = reloadKWin;
    };

    systemd.user.services.kwin-reconfigure-kryonix = {
      Unit = {
        Description = "Kryonix: reconfigure KWin after Home Manager activation";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -lc '${reloadKWin}'";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
