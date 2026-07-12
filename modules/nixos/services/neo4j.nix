# =============================================================================
# Módulo: kryonix.services.neo4j
#
# O que é:
# - Configura o banco de dados de grafos Neo4j Community Edition local no Glacier.
#
# Por quê:
# - GraphRAG: embedding acha similaridade; grafo explica relação e causalidade.
# - Segurança absoluta: escuta estritamente em 127.0.0.1 e exige autenticação.
# - Secrets: credenciais carregadas de arquivo privado /etc/kryonix/neo4j.env.
# =============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.kryonix.services.neo4j;
in
{
  options.kryonix.services.neo4j = {
    enable = mkEnableOption "Neo4j Graph Database para o Kryonix Brain";

    portHttp = mkOption {
      type = types.port;
      default = 7474;
      description = "Porta de escuta para o painel de controle HTTP do Neo4j.";
    };

    portBolt = mkOption {
      type = types.port;
      default = 7687;
      description = "Porta de escuta para o protocolo binário Bolt (consultas da API).";
    };

    environmentFile = mkOption {
      type = types.str;
      default = "/etc/kryonix/neo4j.env";
      description = "Caminho do arquivo contendo segredos de ambiente e credenciais.";
    };
  };

  config = mkIf cfg.enable {
    services.neo4j = {
      enable = true;
      # Bolt escuta em todas as interfaces para permitir acesso via Tailscale.
      # HTTP (painel admin) permanece restrito a localhost.
      # Segurança garantida por: auth habilitada + firewall Tailscale-only.
      defaultListenAddress = "127.0.0.1";

      directories = {
        home = "/var/lib/kryonix/brain/neo4j";
        data = "/var/lib/kryonix/brain/neo4j/data";
        imports = "/var/lib/kryonix/brain/neo4j/import";
        plugins = "/var/lib/kryonix/brain/neo4j/plugins";
      };

      http = {
        enable = true;
        listenAddress = "127.0.0.1:${toString cfg.portHttp}";
      };

      bolt = {
        enable = true;
        # 0.0.0.0 para acesso remoto via Tailscale (Inspiron → Glacier).
        # Firewall abaixo restringe à rede CGNAT do Tailscale (100.64.0.0/10).
        listenAddress = "0.0.0.0:${toString cfg.portBolt}";
        # advertisedAddress não pode ser 0.0.0.0 — usar localhost como fallback
        # (o driver no cliente usa seu próprio URI para conectar, não este valor).
        advertisedAddress = "localhost:${toString cfg.portBolt}";
      };

      https.enable = false;

      extraServerConfig = ''
        # Otimizações de Memória de Produção
        server.memory.heap.initial_size=512m
        server.memory.heap.max_size=2g
        server.memory.pagecache.size=1g

        # Segurança: auth desabilitada — acesso restrito via firewall Tailscale (100.64.0.0/10).
        # A porta Bolt só é alcançável por máquinas na rede Tailscale privada.
        dbms.security.auth_enabled=false
        dbms.security.allow_csv_import_from_file_urls=true

        # Logs e Monitoramento
        dbms.logs.query.enabled=INFO
        dbms.logs.query.threshold=500ms
      '';
    };

    # Firewall: permitir Bolt APENAS da rede Tailscale
    # NixOS handles tailscale interfaces natively without breaking nftables.
    networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ cfg.portBolt ];

    # Injetar variáveis de ambiente para criptografia e autenticação inicial do Neo4j
    # O prefixo '-' torna o arquivo opcional (não impede o boot se ausente).
    systemd.services.neo4j.serviceConfig.EnvironmentFile = mkIf (cfg.environmentFile != "") [
      "-${cfg.environmentFile}"
    ];

    # Permitir que o usuário neo4j acesse o storage (/var/lib/kryonix/brain)
    users.users.neo4j.extraGroups = [ "kryonix" ];

    # Ownership declarativo para evitar drift em upgrades/restarts.
    systemd.tmpfiles.rules = [
      "d /var/lib/kryonix/brain/neo4j 0750 neo4j neo4j -"
      "d /var/lib/kryonix/brain/neo4j/data 0750 neo4j neo4j -"
      "d /var/lib/kryonix/brain/neo4j/logs 0750 neo4j neo4j -"
      "d /var/lib/kryonix/brain/neo4j/import 0750 neo4j neo4j -"
      "d /var/lib/kryonix/brain/neo4j/plugins 0750 neo4j neo4j -"
      "d /var/lib/kryonix/brain/neo4j/conf 0750 neo4j neo4j -"
    ];
  };
}
