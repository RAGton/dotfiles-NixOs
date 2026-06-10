{ config, lib, pkgs, ... }:
let cfg = config.kryonix.features.ai; in
{
  options.kryonix.features.ai = {
    ollama.enable = lib.mkEnableOption "Ollama LLM runtime";
    openWebui.enable = lib.mkEnableOption "Open WebUI for Ollama";
    neo4j.enable = lib.mkEnableOption "Neo4j graph database";
    lightrag.enable = lib.mkEnableOption "LightRAG retrieval engine";
    kryonixBrain.enable = lib.mkEnableOption "Kryonix Brain AI ecosystem";
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.ollama.enable {
      services.ollama = {
        enable = true;
        acceleration = lib.mkDefault "cuda";
      };
    })
    (lib.mkIf cfg.neo4j.enable {
      services.neo4j.enable = true;
    })
  ];
}
