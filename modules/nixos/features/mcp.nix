{ config, lib, pkgs, ... }:
let cfg = config.kryonix.features.mcp; in
{
  options.kryonix.features.mcp = {
    filesystem.enable = lib.mkEnableOption "Filesystem MCP integration";
    github.enable = lib.mkEnableOption "GitHub MCP integration";
    neo4j.enable = lib.mkEnableOption "Neo4j MCP integration";
    ollama.enable = lib.mkEnableOption "Ollama MCP integration";
  };
  config = {};
}
