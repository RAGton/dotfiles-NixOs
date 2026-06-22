{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kryonix.home.features.browser;
in
{
  options.kryonix.home.features.browser = {
    firefox.enable = lib.mkEnableOption "Firefox browser";
    chromium.enable = lib.mkEnableOption "Chromium browser";
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.firefox.enable {
      programs.firefox.enable = true;
    })
    (lib.mkIf cfg.chromium.enable {
      programs.chromium.enable = true;
    })
  ];
}
