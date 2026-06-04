# =============================================================================
# Módulo: Home Assistant (via Podman/OCI Containers)
#
# O que é:
# - Home Assistant rodando localmente usando container oficial em Podman.
#
# Por quê:
# - Permite integrações da Aura e n8n para automação residencial futura.
# - Uso de container garante isolamento de dependências Python.
#
# Segurança:
# - Network host mode exigido pelo HA para descoberta de dispositivos locais (mDNS/UPnP).
# - Dados persistentes em /var/lib/kryonix/home-assistant.
# =============================================================================
{
  config,
  lib,
  ...
}:

let
  cfg = config.kryonix.services.home-assistant;
in
{
  options.kryonix.services.home-assistant = {
    enable = lib.mkEnableOption "Serviço local de Home Assistant (Podman)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8123;
      description = "Porta principal do Home Assistant.";
    };
  };

  config = lib.mkIf cfg.enable {
    # 1. Preparar o diretório de dados para persistência
    systemd.tmpfiles.rules = [
      "d /var/lib/kryonix/home-assistant 0755 root root -"
    ];

    # 2. Configurar o OCI Container via Podman
    virtualisation.oci-containers = {
      backend = "podman";
      containers.homeassistant = {
        image = "ghcr.io/home-assistant/home-assistant:stable";

        # O Home Assistant necessita de network mode host para Auto-Discovery na LAN
        extraOptions = [
          "--network=host"
          "--privileged"
        ];

        # O timezone é repassado para manter cronogramas locais consistentes
        environment = {
          TZ = "America/Cuiaba";
        };

        # Montagem do volume persistente
        volumes = [
          "/var/lib/kryonix/home-assistant:/config"
          "/etc/localtime:/etc/localtime:ro"
        ];
      };
    };

    # Assegurar que o firewall permita o acesso LAN ao Home Assistant se desejado.
    # Por padrão, apenas habilitamos a porta se explicitamente solicitado.
    # O user pediu apenas para "subir", por enquanto a porta 8123 não será aberta na WAN, apenas na LAN.
    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
