# =============================================================================
# Kryonix Bar Backend Service
#
# O que é:
# - Gerencia o ciclo de vida do backend D-Bus da Kryonix Bar (Rust).
# - Expõe org.kryonix.Bar para consumo pelo frontend.
# =============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.kryonix-bar;
in
{
  options.services.kryonix-bar = {
    enable = lib.mkEnableOption "Kryonix Bar Backend Service";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.kryonix-bar-backend;
      description = "Pacote da Kryonix Bar (Backend).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.kryonix-bar = {
      Unit = {
        Description = "Kryonix Bar Backend (D-Bus API)";
        After = [ "graphical-session-pre.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = "${cfg.package}/bin/kryonix-bar-backend";
        Restart = "on-failure";
        RestartSec = "5s";
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
