{ config, lib, pkgs, ... }:
let cfg = config.kryonix.home.features.terminal; in
{
  options.kryonix.home.features.terminal = {
    warp.enable = lib.mkEnableOption "Warp Terminal";
    kitty.enable = lib.mkEnableOption "Kitty terminal emulator";
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.warp.enable {
      home.packages = with pkgs; [ warp-terminal ];
    })
    (lib.mkIf cfg.kitty.enable {
      programs.kitty.enable = true;
    })
  ];
}
