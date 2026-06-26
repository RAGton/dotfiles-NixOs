{
  config,
  lib,
  ...
}:

let
  cfg = config.kryonix.profiles.workstation-gamer;
in
{
  options.kryonix.profiles.workstation-gamer = {
    enable = lib.mkEnableOption "Profile de Workstation e Gaming (Glacier)";
  };

  config = lib.mkIf cfg.enable {
    kryonix.features.gaming = {
      enable = lib.mkDefault true;
      steam.gamescope = lib.mkDefault true;
      lutris.enable = lib.mkDefault false;
      wineTools.enable = lib.mkDefault false;
      nvtop.enable = lib.mkDefault false;
      performanceGovernor = lib.mkDefault true;
    };
  };
}
