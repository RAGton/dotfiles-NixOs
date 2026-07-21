{
  config,
  lib,
  pkgs,
  ...
}:

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
    security.pam.services.kryxd = { };

    systemd.services.kryxd = {
      description = "Kryonix Management Daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        PORT = toString cfg.port;
        KRYONIX_INSTALLER_BIND = lib.mkDefault "0.0.0.0:${toString cfg.port}";
        KRYONIX_ALLOW_REMOTE_BIND = lib.mkDefault "1";
        RUST_LOG = "info";
      }
      // (lib.optionalAttrs (cfg.token != null) {
        KRYONIX_INSTALLER_TOKEN = cfg.token;
      });

      serviceConfig = {
        ExecStart = "${pkgs.kryxd}/bin/kryxd";
        Restart = "always";
        User = "root";
        Group = "root";
      };
    };

    networking.firewall.allowedTCPPorts = [
      config.services.kryxd.port
      3000
      5173
    ];
  };
}
