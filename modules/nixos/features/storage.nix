{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kryonix.features.storage;
in
{
  options.kryonix.features.storage = {
    srvData.enable = lib.mkEnableOption "Dedicated /srv/data mount";
    aiModels.enable = lib.mkEnableOption "Pre-cache AI models on /srv/data";
  };
  config = { };
}
