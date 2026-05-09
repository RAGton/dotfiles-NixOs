{ config, lib, pkgs, ... }:

let
  cfg = config.services.kryonix.homeBrain;
in
{
  options.services.kryonix.homeBrain = {
    enable = lib.mkEnableOption "Kryonix Home Brain";

    user = lib.mkOption {
      type = lib.types.str;
      default = "rocha";
      description = "Usuário dono da Home a ser organizada.";
    };

    defaultMode = lib.mkOption {
      type = lib.types.enum [ "dry-run" "manual" ];
      default = "dry-run";
      description = "Modo padrão. Nunca usar apply automático inicialmente.";
    };

    watchedDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "Downloads"
        "Documentos"
        "Imagens"
        "Vídeos"
        "Músicas"
        "Desktop"
        "Área de Trabalho"
        "Pictures"
        "Videos"
        "Music"
      ];
      description = "Diretórios relativos à Home que podem ser escaneados.";
    };

    ignoreHidden = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Ignorar pastas e arquivos ocultos.";
    };

    enableTimer = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Ativar timer systemd user futuramente.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.defaultMode == "dry-run";
        message = "Kryonix Home Brain deve iniciar em dry-run por segurança.";
      }
    ];

    environment.systemPackages = [
      # Futuro:
      # pkgs.kryonix-home
    ];

    # Rascunho futuro:
    #
    # systemd.user.services.kryonix-home-daemon = {
    #   description = "Kryonix Home Brain daemon";
    #   wantedBy = [ "default.target" ];
    #   serviceConfig = {
    #     Type = "simple";
    #     ExecStart = "${pkgs.kryonix-home}/bin/kryonix-home daemon --mode dry-run";
    #     Restart = "on-failure";
    #   };
    # };
    #
    # systemd.user.timers.kryonix-home-scan = lib.mkIf cfg.enableTimer {
    #   wantedBy = [ "timers.target" ];
    #   timerConfig = {
    #     OnCalendar = "hourly";
    #     Persistent = true;
    #   };
    # };
  };
}
