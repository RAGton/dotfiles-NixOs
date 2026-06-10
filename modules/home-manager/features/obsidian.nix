{ config, lib, pkgs, ... }:
let cfg = config.kryonix.home.features.obsidian; in
{
  options.kryonix.home.features.obsidian = {
    vault.enable = lib.mkEnableOption "Obsidian vault integration";
  };
  config = lib.mkIf cfg.vault.enable {
    home.packages = with pkgs; [ obsidian ];
  };
}
