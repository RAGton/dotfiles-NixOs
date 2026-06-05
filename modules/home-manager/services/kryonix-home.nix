{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.kryonix.services.smart-filer;
in
{
  options.kryonix.services.smart-filer = {
    enable = mkEnableOption "Daemon de Organização Semântica de Arquivos";
    watchPaths = mkOption {
      type = types.listOf types.str;
      default = [
        "%h/Downloads"
        "%h/Inbox_IA"
      ];
      description = "Diretórios monitorados pelo Smart Filer.";
    };
  };

  config = mkIf cfg.enable {
    # 1. O Gatilho de Caminho (Systemd Path Unit)
    # Monitora nativamente via inotify do Kernel
    systemd.user.paths.kryonix-home = {
      Unit = {
        Description = "Kryonix Home Watchdog Path Monitor";
      };
      Path = {
        # Dispara quando o diretório receber modificações ou novos arquivos
        PathChanged = cfg.watchPaths;
      };
      Install = {
        WantedBy = [ "paths.target" ];
      };
    };

    # 2. O Serviço que executa o processamento (Systemd Service Unit)
    # Removido o subcomando inválido 'watch'. Roda de forma atômica e morre.
    systemd.user.services.kryonix-home = {
      Unit = {
        Description = "Kryonix Home Context-Aware File Processing Service";
        After = [
          "network.target"
          "tailscaled.service"
        ];
      };
      Service = {
        Type = "oneshot";
        # Executa o binário puro; ele escaneia e processa a Inbox de forma limpa
        # Utilizando autopilot --execute --inbox para rodar atomicamente e fechar
        ExecStart = "${pkgs.kryonix-home}/bin/kryonix-home autopilot --execute --inbox";
        EnvironmentFile = "/etc/kryonix/brain.env";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };
  };
}
