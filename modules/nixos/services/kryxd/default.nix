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

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Endereço de escuta do painel e da API do kryxd";
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
        KRYONIX_INSTALLER_BIND = "${cfg.listenAddress}:${toString cfg.port}";
        KRYONIX_ALLOW_REMOTE_BIND = if cfg.listenAddress == "127.0.0.1" then "0" else "1";
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
        # Silence the boot banner that prints `KRYONIX INSTALLER TOKEN: <uuid>` to journal.
        # The token itself comes from env var KRYONIX_INSTALLER_TOKEN (or a generated UUID);
        # we no longer rely on stdout for visibility because systemd's journal then captures
        # it on every boot. Callers use the X-Kryonix-Installer-Token header.
        # Rationale: see kryonix-iso-loop-001 / EVIDENCE.md (TOK-001, ~39 banner lines).
        LogLevelMax = "err";
        StandardOutput = "null";
        StandardError = "journal";
      };
    };

    networking.firewall.allowedTCPPorts = [
      3000
      5173
    ]
    ++ lib.optional (cfg.listenAddress != "127.0.0.1") cfg.port;
  };
}
