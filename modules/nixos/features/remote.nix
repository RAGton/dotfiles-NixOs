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
