{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kryonix.features.etcher;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.etcher ];
  };
}
