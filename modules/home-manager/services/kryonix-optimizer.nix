{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.kryonix.services.ram-optimizer;
in {
  options.kryonix.services.ram-optimizer = {
    enable = mkEnableOption "Daemon Otimizador Vivo de RAM do Kryonix";
  };

  config = mkIf cfg.enable {
    systemd.user.services.kryonix-optimizer = {
      Unit = {
        Description = "Kryonix RAM Optimizer AI Daemon";
        After = [ "network.target" "tailscaled.service" ];
      };
      Service = {
        ExecStart = "${pkgs.kryonix-optimizer}/bin/kryonix-optimizer";
        EnvironmentFile = "/etc/kryonix/brain.env";
        Restart = "on-failure";
        RestartSec = "15";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
