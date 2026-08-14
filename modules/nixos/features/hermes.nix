{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.kryonix.features.hermes;

  hasWorkspace = cfg.workspacePath != null;
  hasVault = cfg.vaultPath != null;

  computedPersistentDataPath =
    if cfg.persistentDataPath != null then
      cfg.persistentDataPath
    else if hasWorkspace then
      "${cfg.workspacePath}/.hermes/data"
    else
      "/home/rocha/.hermes/data"; # Fallback

  volumeMode = if cfg.readOnly then "ro" else "rw";
in
{
  options.kryonix.features.hermes = {
    enable = lib.mkEnableOption "Hermes Agent via Podman OCI";

    readOnly = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Mapear volumes como read-only (true) ou read-write (false).";
    };

    workspacePath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Caminho absoluto do workspace de desenvolvimento.";
    };

    vaultPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Caminho absoluto do Obsidian Vault.";
    };

    persistentDataPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Caminho absoluto para persistência de dados do Hermes.";
    };

    guiLauncher = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Criar atalho GUI (.desktop) para o Hermes Desktop.";
      };

      asService = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Quando true, o hermes-desktop é iniciado como serviço systemd user
          (hermes-desktop.service) junto com a sessão gráfica, garantindo que o
          GUI do agente fique sempre disponível sem precisar abrir manualmente.
        '';
      };

      execCommand = lib.mkOption {
        type = lib.types.str;
        default = "${pkgs.xdg-utils}/bin/xdg-open http://127.0.0.1:8080";
        description = "Comando disparado pelo atalho Desktop e pelo serviço.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.hermes-agent = {
      image = "local/hermes-agent:latest";
      volumes =
        [ ]
        ++ lib.optional hasWorkspace "${cfg.workspacePath}:/workspace:${volumeMode}"
        ++ lib.optional hasVault "${cfg.vaultPath}:/vault:${volumeMode}"
        ++ [ "${computedPersistentDataPath}:/root/.hermes:${volumeMode}" ];

      extraOptions = [
        "--userns=keep-id"
        "--add-host=host.containers.internal:host-gateway"
      ];
      environmentFiles = [ "/run/secrets/hermes.env" ];
      autoStart = true;
    };

    # Atalho .desktop no menu de aplicativos para abrir o Hermes Desktop.
    environment.systemPackages = lib.mkIf cfg.guiLauncher.enable [
      (pkgs.makeDesktopItem {
        name = "hermes-agent";
        desktopName = "Hermes Agent";
        exec = cfg.guiLauncher.execCommand;
        icon = "utilities-terminal"; # Ícone padrão, pode ser ajustado
        comment = "Lançador do Assistente Simbiótico Hermes";
        categories = [
          "Utility"
          "Development"
        ];
      })
    ];

    # Serviço systemd user: mantém o GUI do Hermes Desktop sempre vivo na sessão.
    # Ativado via guiLauncher.asService = true no host.
    home-manager.sharedModules = lib.mkIf (cfg.guiLauncher.enable && cfg.guiLauncher.asService) [
      {
        systemd.user.services.hermes-desktop = {
          Unit = {
            Description = "Hermes Agent Desktop GUI";
            Documentation = "https://github.com/RAGton/kryonix";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = cfg.guiLauncher.execCommand;
            Restart = "on-failure";
            RestartSec = "5s";
            # Não tentar reiniciar indefinidamente na primeira hora de sessão
            StartLimitBurst = 5;
            StartLimitIntervalSec = 300;
          };
          Install = {
            WantedBy = [ "graphical-session.target" ];
          };
        };
      }
    ];
  };
}
