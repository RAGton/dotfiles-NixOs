{ config, lib, pkgs, ... }:

let
  cfg = config.kryonix.kcp;
  uiPortIsPrivileged = cfg.uiPort < 1024;
in
{
  options.kryonix.kcp = {
    enable = lib.mkEnableOption "Kryonix Control Plane (Backend + UI)";

    apiPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Porta interna do backend kryxd (sempre 127.0.0.1).";
    };

    uiPort = lib.mkOption {
      type = lib.types.port;
      default = 443;
      description = "Porta publica do proxy reverso. Portas < 1024 ativam Nginx.";
    };

    capabilitiesPath = lib.mkOption {
      type = lib.types.path;
      default = /etc/kryonix/identity.json;
      description = "Caminho do manifesto de identidade consumido pela API.";
    };

    enableProxy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Liga o proxy reverso Nginx. Disable = bind direto na apiPort (dev).";
    };
  };

  config = lib.mkIf cfg.enable {
    # Backend confinado ao loopback (services.kryxd ja existe em services/kryxd/default.nix)
    services.kryxd = {
      enable = true;
      port = cfg.apiPort;
      listenAddress = "127.0.0.1";
    };

    # Contrato de capabilities consumido pela UI
    environment.etc."kryonix/capabilities.json".source = cfg.capabilitiesPath;

    # Hardening do daemon
    systemd.services.kryxd.serviceConfig = {
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ReadWritePaths = [ "/var/lib/kryonix" "/var/log/kryxd" ];
    };

    # Proxy reverso so em porta privilegiada (443/80) - evita surpresas em dev
    services.nginx = lib.mkIf (cfg.enableProxy && uiPortIsPrivileged) {
      enable = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      virtualHosts."_" = {
        listen = [ { addr = "0.0.0.0"; port = cfg.uiPort; } ];
        locations."/api/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.apiPort}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
        # UI estatica servida pelo proprio kryxd (single source of truth)
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.apiPort}";
          proxyWebsockets = true;
        };
      };
    };

    # Firewall: apenas a uiPort eh publica
    networking.firewall.allowedTCPPorts = lib.optional cfg.enableProxy cfg.uiPort;
  };
}
