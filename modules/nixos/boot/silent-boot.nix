{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kryonix.boot.silent;
in
{
  options.kryonix.boot.silent = {
    enable = lib.mkEnableOption "Habilitar Silent Boot (Kernel silencioso e supressão de logs de console)";

    enableEarlyKms = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Carregar drivers de vídeo no initrd para evitar flicker antes do Plymouth.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.verbose = false;
    boot.consoleLogLevel = 0;

    boot.kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];

    # Carrega drivers KMS apenas se ativado e evita forçar nouveau indiscriminadamente
    boot.initrd.kernelModules = lib.mkIf cfg.enableEarlyKms (
      [
        "amdgpu"
        "i915"
      ]
      ++ lib.optionals (!config.hardware.nvidia.modesetting.enable) [ "nouveau" ]
    );

    # Garante a ativação do serviço de splash screen
    boot.plymouth.enable = lib.mkDefault true;
  };
}
