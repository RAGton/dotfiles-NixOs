{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.kryonix.performance.schedExt;
in
{
  options.kryonix.performance.schedExt = {
    enable = lib.mkEnableOption "Suporte a sched-ext";

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Inicia automaticamente o scheduler selecionado.
        Deve permanecer false até os benchmarks serem concluídos.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.scx.full;
      defaultText = lib.literalExpression "pkgs.scx.full";
      description = "Pacote contendo os schedulers sched-ext.";
    };

    scheduler = lib.mkOption {
      type = lib.types.str;
      default = "scx_flash";
      description = "Scheduler usado quando autoStart estiver habilitado.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Argumentos entregues diretamente ao scheduler.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Disponibiliza os schedulers mesmo com autostart desligado.
    environment.systemPackages = [
      cfg.package
    ];

    services.scx = {
      enable = cfg.autoStart;
      package = cfg.package;
      scheduler = cfg.scheduler;
      extraArgs = cfg.extraArgs;
    };

    assertions = [
      {
        assertion =
          lib.versionAtLeast
            config.boot.kernelPackages.kernel.version
            "6.12";

        message = ''
          kryonix.performance.schedExt requer kernel Linux 6.12 ou superior.
        '';
      }
      {
        assertion =
          builtins.elem cfg.scheduler cfg.package.schedulers;

        message = ''
          Scheduler sched-ext inválido: ${cfg.scheduler}.
          Disponíveis: ${lib.concatStringsSep ", " cfg.package.schedulers}
        '';
      }
    ];
  };
}
