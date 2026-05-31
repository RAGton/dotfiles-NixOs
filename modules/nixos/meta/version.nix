# ==============================================================================
# Módulo: Meta Version & Telemetry
# Autor: Gabriel Aguiar Rocha (RAGton) + Gemini CLI
#
# O que é:
# - Gerencia a identificação da versão do Kryonix (/etc/kryonix-version).
# - Provê telemetria opcional para observabilidade da distro.
# ==============================================================================
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.kryonix.meta.version;
  self = inputs.self;
  
  # Captura a revisão do commit do input 'self' (o próprio repositório)
  commit = self.rev or self.dirtyRev or "dirty-${self.lastModifiedDate or "unknown"}";
  timestamp = self.lastModifiedDate or "unknown";
  versionContent = ''
    KRYONIX_REV=${commit}
    KRYONIX_BUILD_TIME=${timestamp}
    KRYONIX_PRETTY_NAME="Kryonix Distro (v${lib.substring 0 8 commit})"
  '';
in
{
  options.kryonix.meta.version = {
    enable = lib.mkEnableOption "Observabilidade e versionamento do Kryonix";

    telemetry = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enviar ping semanal de telemetria anônima.";
      };
      endpoint = lib.mkOption {
        type = lib.types.str;
        default = "https://telemetry.kryonix.org/ping";
        description = "URL para envio do ping de telemetria.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # 1. Arquivo de versão em /etc
    environment.etc."kryonix-version".text = versionContent;

    # Exporta para acessibilidade via Nix
    system.build.kryonix-version = {
      inherit commit timestamp;
      prettyName = "Kryonix Distro (v${lib.substring 0 8 commit})";
    };

    # 2. Telemetria Semanal
    systemd.services.kryonix-telemetry = lib.mkIf cfg.telemetry.enable {
      description = "Kryonix Distro Telemetry Ping";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''
          ${pkgs.curl}/bin/curl -X POST \
            -H "Content-Type: application/json" \
            -d '{"rev": "${commit}", "timestamp": "${timestamp}", "hostname": "${config.networking.hostName}"}' \
            ${cfg.telemetry.endpoint}
        '';
        # Segurança: roda como usuário dinâmico e restrito
        DynamicUser = true;
        ProtectSystem = "full";
        PrivateTmp = true;
      };
    };

    systemd.timers.kryonix-telemetry = lib.mkIf cfg.telemetry.enable {
      description = "Weekly Kryonix Telemetry Timer";
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
      wantedBy = [ "timers.target" ];
    };
  };
}
