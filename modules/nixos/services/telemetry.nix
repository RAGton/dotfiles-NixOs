{ config, lib, pkgs, ... }:

let
  cfg = config.kryonix.services.telemetry;
in
{
  options.kryonix.services.telemetry = {
    enable = lib.mkEnableOption "Kryonix Telemetry Heartbeat";
  };

  config = lib.mkIf cfg.enable {
    systemd.services.kryx-telemetry = {
      description = "Kryonix Telemetry Heartbeat";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.kryx}/bin/kryx system report";
        User = "root";
      };
    };

    systemd.timers.kryx-telemetry = {
      description = "Run Kryonix Telemetry every hour";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
      };
    };
  };
}
