{ config, lib, pkgs, ... }:
let cfg = config.kryonix.home.features.ai; in
{
  options.kryonix.home.features.ai = {
    claude.enable = lib.mkEnableOption "Claude Desktop";
    gemini.enable = lib.mkEnableOption "Gemini Web Wrapper";
    ollamaCli.enable = lib.mkEnableOption "Ollama CLI";
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.claude.enable {
      home.packages = with pkgs; [ zed-editor ]; # placeholder
    })
    (lib.mkIf cfg.gemini.enable {
      # Gemini não tem package Nix direto; placeholder seguro.
    })
    (lib.mkIf cfg.ollamaCli.enable {
      home.packages = with pkgs; [ ollama ];
    })
  ];
}
