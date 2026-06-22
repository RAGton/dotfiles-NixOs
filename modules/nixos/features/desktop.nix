{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.kryonix.features.desktop;
in
{
  options.kryonix.features.desktop = {
    plasma.enable = lib.mkEnableOption "KDE Plasma 6 desktop environment";
    audio.enable = lib.mkEnableOption "PipeWire audio server";
    bluetooth.enable = lib.mkEnableOption "Bluetooth support";
    printing.enable = lib.mkEnableOption "CUPS printing service";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.plasma.enable {
      services.desktopManager.plasma6.enable = true;
      services.displayManager.sddm.enable = true;
    })

    (lib.mkIf cfg.audio.enable {
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
      };
    })

    (lib.mkIf cfg.bluetooth.enable {
      hardware.bluetooth.enable = true;
      hardware.bluetooth.powerOnBoot = true;
    })

    (lib.mkIf cfg.printing.enable {
      services.printing.enable = true;
    })
  ];
}
