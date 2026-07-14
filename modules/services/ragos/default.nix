{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.kryonix.services.ragos-think;
  # Importar o helper
  inherit (import ../../../lib/services.nix { inherit lib; }) mkKryonixService;
in
{
  options.kryonix.services.ragos-think = {
    enable = lib.mkEnableOption "RAGOS Think Service";

    serverIp = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "IP primário do servidor RAGOS.";
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 80;
      description = "Porta HTTP do servidor.";
    };

    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "America/Sao_Paulo";
      description = "Fuso horário.";
    };

    wanMode = lib.mkOption {
      type = lib.types.enum [
        "dhcp"
        "static"
        "pppoe"
        "none"
      ];
      default = "dhcp";
      description = "Modo de configuração da porta WAN.";
    };

    pppoeUser = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Usuário PPPoE (se aplicável).";
    };

    pppoePassword = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Senha PPPoE (se aplicável).";
    };
  };

  config = lib.mkIf cfg.enable (mkKryonixService {
    name = "ragos-think";
    files = {
      "params.nix" = pkgs.writeText "params.nix" ''
        {
          serverIp = "${cfg.serverIp}";
          httpPort = ${toString cfg.httpPort};
          timeZone = "${cfg.timeZone}";
          wanMode = "${cfg.wanMode}";
          pppoeUser = "${cfg.pppoeUser}";
        }
      '';
    }
    // lib.optionalAttrs (cfg.wanMode == "pppoe") {
      "wan-pppoe.env" = pkgs.writeText "wan-pppoe.env" ''
        PPPOE_USER=${cfg.pppoeUser}
        PPPOE_PASSWORD=${cfg.pppoePassword}
      '';
    };

    # Cria os links legados automaticamente para não quebrar scripts antigos
    legacyLinks = {
      "/var/lib/ragos/runtime/params.nix" = "params.nix";
    }
    // lib.optionalAttrs (cfg.wanMode == "pppoe") {
      "/etc/ragos/wan-pppoe.env" = "wan-pppoe.env";
    };
  });
}
