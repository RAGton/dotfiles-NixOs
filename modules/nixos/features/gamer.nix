{ config, lib, pkgs, ... }:

let
  cfg = config.kryonix.features.gamer;
in
{
  options.kryonix.features.gamer = {
    steam.enable = lib.mkEnableOption "Steam gaming platform";
    gamemode.enable = lib.mkEnableOption "GameMode performance tuning";
    mangohud.enable = lib.mkEnableOption "MangoHud overlay";
    proton.enable = lib.mkEnableOption "Proton compatibility layer";
    controllers.enable = lib.mkEnableOption "Game controller support";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.steam.enable {
      programs.steam.enable = true;
      programs.steam.remotePlay.openFirewall = true;
    })

    (lib.mkIf cfg.gamemode.enable {
      programs.gamemode.enable = true;
    })

    (lib.mkIf cfg.mangohud.enable {
      environment.systemPackages = with pkgs; [ mangohud ];
    })

    (lib.mkIf cfg.controllers.enable {
      hardware.xpadneo.enable = lib.mkDefault true;
    })
  ];
}
