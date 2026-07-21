{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kryonix.features.ntfs;
in
{
  config = lib.mkIf cfg.enable {
    boot.supportedFilesystems = [ "ntfs" ];
    environment.systemPackages = [ pkgs.ntfs3g ];
  };
}
