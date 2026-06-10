{ config, lib, pkgs, ... }:
let cfg = config.kryonix.features.remote; in
{
  options.kryonix.features.remote = {
    webInstaller.enable = lib.mkEnableOption "Kryonix Web Installer remote access";
    vnc.enable = lib.mkEnableOption "VNC remote desktop";
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.vnc.enable {
      services.xrdp.enable = true;
    })
  ];
}
