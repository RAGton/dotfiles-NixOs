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
    webInstaller = {
      enable = lib.mkEnableOption "Kryonix Web Installer remote access";
    };
    vnc = {
      enable = lib.mkEnableOption "VNC remote desktop";
    };
    ssh = {
      enable = lib.mkEnableOption "OpenSSH remote access";

      ports = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [ 22 ];
        description = "OpenSSH listening ports.";
      };

      permitRootLogin = lib.mkOption {
        type = lib.types.enum [
          "yes"
          "without-password"
          "prohibit-password"
          "forced-commands-only"
          "no"
        ];
        default = "no";
        description = "OpenSSH PermitRootLogin policy.";
      };

      passwordAuthentication = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Allow password authentication over SSH.";
      };

      kbdInteractiveAuthentication = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Allow keyboard-interactive authentication.";
      };

      x11Forwarding = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Allow X11 forwarding.";
      };

      allowTcpForwarding = lib.mkOption {
        type = lib.types.str;
        default = "yes";
        description = "Allow TCP forwarding. Useful for SSH tunnels.";
      };

      logLevel = lib.mkOption {
        type = lib.types.enum [
          "QUIET"
          "FATAL"
          "ERROR"
          "INFO"
          "VERBOSE"
          "DEBUG"
          "DEBUG1"
          "DEBUG2"
          "DEBUG3"
        ];
        default = "VERBOSE";
        description = "OpenSSH log verbosity.";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to open SSH ports in the firewall. Disabled by default to avoid exposing SSH accidentally.";
      };
    };
  };

  config = lib.mkMerge [
    # WebInstaller (existing)
    (lib.mkIf cfg.webInstaller.enable {
      # TODO: implement webInstaller if needed
    })

    # VNC (existing)
    (lib.mkIf cfg.vnc.enable {
      services.xrdp.enable = true;
    })

    # SSH
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

      networking.firewall.allowedTCPPorts = lib.mkIf cfg.ssh.openFirewall cfg.ssh.ports;
    })
  ];
}
