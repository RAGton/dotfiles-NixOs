{ config, lib, pkgs, ... }:

let
  cfg = config.services.kryxd;
in
{
  options.services.kryxd = {
    enable = lib.mkEnableOption "Kryonix Management Daemon (kryxd)";
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Porta em que o kryxd vai escutar";
    };

    token = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Token fixo para automação (opcional, senão gera dinâmico)";
    };
  };

  config = lib.mkIf cfg.enable {
    security.pam.services.kryxd = {};

    systemd.services.kryxd = {
      description = "Kryonix Management Daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        PORT = toString cfg.port;
        RUST_LOG = "info";
      } // (lib.optionalAttrs (cfg.token != null) {
        KRYONIX_INSTALLER_TOKEN = cfg.token;
      });

      serviceConfig = {
        ExecStart = "${pkgs.kryxd}/bin/kryxd";
        Restart = "always";
        User = "root";
        Group = "root";
      };
    };
  };
}
