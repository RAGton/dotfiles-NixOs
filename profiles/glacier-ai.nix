# =============================================================================
# Profile: glacier-ai
#
# O que é:
# - Habilita Ollama + Brain API + LightRAG no Glacier.
# - Ollama sem autostart: GPU fica livre até start manual.
# - keep_alive=0: modelo descarregado da VRAM após cada query.
#
# Por quê:
# - Separação limpa: IA não afeta gaming.
# - VRAM da RTX 4060 (8 GB) fica disponível para jogos quando Ollama parado.
# - Controle manual: kryonix ollama start/stop
#
# Como usar:
#   kryonix.profiles.glacier-ai.enable = true;
#
# Modo gamer (desligar IA temporariamente):
#   systemctl stop ollama kryonix-lightrag kryonix-brain-api
# =============================================================================
{
  config,
  lib,
  ...
}:

let
  cfg = config.kryonix.profiles.glacier-ai;
in
{
  options.kryonix.profiles.glacier-ai = {
    enable = lib.mkEnableOption "Perfil IA do Glacier (Ollama + Brain + LightRAG, sem autostart)";

    model = lib.mkOption {
      type = lib.types.str;
      default = "qwen2.5-coder:7b";
      description = "Modelo Ollama padrão para o Glacier.";
    };

    keepAlive = lib.mkOption {
      type = lib.types.str;
      default = "0";
      description = ''
        Tempo de keep-alive do modelo em VRAM.
        "0" = descarrega imediatamente (recomendado para Glacier gamer).
      '';
    };

    vramProfile = lib.mkOption {
      type = lib.types.enum [
        "ai"
        "balanced"
        "gaming"
      ];
      default = "balanced";
      description = "Perfil de VRAM: ai (exigente), balanced (misto), gaming (prioriza GPU).";
    };

    vramWarnOnly = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Se true, apenas avisa em caso de VRAM baixa.";
    };
  };

  config = lib.mkIf cfg.enable {
    kryonix.services.brain = {
      enable = true;
      role = "server";
      bindHost = "0.0.0.0";

      # Perfil de VRAM
      vram = {
        profile = cfg.vramProfile;
        warnOnly = cfg.vramWarnOnly;
      };

      # NÃO iniciar automaticamente no boot (se quiser manter disabled).
      # Start manual: kryonix ollama start → systemctl start ollama
      # Mas o user pediu para habilitar por padrão e remover o model warmup do boot.
      ollamaAutoStart = lib.mkDefault true;
      modelWarmupOnBoot = lib.mkDefault false;

      ollama = {
        enable = true;
        model = cfg.model;
        keepAlive = cfg.keepAlive;
        acceleration = "cuda";
      };
      storagePath = "/var/lib/kryonix/brain/storage";
      vaultPath = "/var/lib/kryonix/vault";
    };

    # Habilita a infraestrutura de grafos Neo4j para GraphRAG
    kryonix.services.neo4j = {
      enable = true;
      portHttp = 7474;
      portBolt = 7687;
      environmentFile = "/etc/kryonix/neo4j.env";
    };
    # Kora removida (assistente legada). Camada Aura preservada em
    # `kryonix.services.aura` — motor de execução a ser redefinido.
    # Ver docs/aura/KORA_RETIREMENT_STUDY.md.
  };
}
