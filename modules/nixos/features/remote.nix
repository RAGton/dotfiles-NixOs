# =============================================================================
# Module: Remote Access features
# =============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kryonix.features.remote;
in
{
  options.kryonix.features.remote = {
    ssh = {
      ports = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [ 22 ];
        description = "Ports to listen on for SSH";
      };
      permitRootLogin = lib.mkOption {
        type = lib.types.str;
        default = "no";
        description = "Whether root login is permitted";
      };
      passwordAuthentication = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to allow password authentication";
      };
      kbdInteractiveAuthentication = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to allow keyboard-interactive authentication";
      };
      x11Forwarding = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to allow X11 forwarding";
      };
      allowTcpForwarding = lib.mkOption {
        type = lib.types.str;
        default = "yes";
        description = "Whether to allow TCP forwarding";
      };
      logLevel = lib.mkOption {
        type = lib.types.str;
        default = "VERBOSE";
        description = "Logging level for sshd";
      };
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to open the firewall for the specified SSH ports";
      };
    };

    webInstaller.enable = lib.mkEnableOption "Kryonix Web Installer remote access";
    vnc.enable = lib.mkEnableOption "VNC remote desktop";

    ssh = {
      enable = lib.mkEnableOption "OpenSSH server daemon (access remoto seguro)";

      port = lib.mkOption {
        type = lib.types.port;
        default = 22;
        description = "Porta para o servidor SSH (aplica-se apenas quando remote.ssh.enable = true)";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.ssh.enable {
      services.openssh = {
        enable = true;
        ports = cfg.ssh.ports;
        settings = {
          PermitRootLogin = cfg.ssh.permitRootLogin;
          PasswordAuthentication = cfg.ssh.passwordAuthentication;
          KbdInteractiveAuthentication = cfg.ssh.kbdInteractiveAuthentication;
          X11Forwarding = cfg.ssh.x11Forwarding;
          AllowTcpForwarding = cfg.ssh.allowTcpForwarding;
          LogLevel = cfg.ssh.logLevel;
        };
      };
    })

    (lib.mkIf (cfg.ssh.enable && cfg.ssh.openFirewall) {
      networking.firewall.allowedTCPPorts = cfg.ssh.ports;
    })

    (lib.mkIf cfg.vnc.enable {
      services.xrdp.enable = true;
    })

    # SSH server
    (lib.mkIf cfg.ssh.enable {
      services.openssh = {
        enable = true;
        ports = [ cfg.ssh.port ];
        settings = {
          PermitRootLogin = "no";
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
        };
      };

      # Abrir porta SSH no firewall
      networking.firewall.allowedTCPPorts = [ cfg.ssh.port ];
    })
  ];
}
