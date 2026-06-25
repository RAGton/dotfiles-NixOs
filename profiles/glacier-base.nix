# =============================================================================
# Profile: glacier-base
#
# O que é:
# - Perfil base do Glacier: NVIDIA driver, graphics, SSH, Tailscale, firewall,
#   sudo, branding e pacotes de diagnóstico.
# - Networking de identidade (IP fixo, bridge, WoL) fica em rve-compat.nix.
#
# Por quê:
# - Separação limpa: base ≠ IA ≠ gamer.
# - Um único lugar para tudo que é "servidor NixOS com GPU NVIDIA".
# =============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.kryonix.profiles.glacier-base;
in
{
  options.kryonix.profiles.glacier-base = {
    enable = lib.mkEnableOption "Perfil base do Glacier (NVIDIA, SSH, Tailscale, firewall, branding)";
  };

  config = lib.mkIf cfg.enable {
    # Performance de servidor
    powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

    # NVIDIA config — removida, agora gerenciada por kryonix.features.gpu.nvidia
    # (declarado em hosts/glacier/default.nix)
    #
    # PRIME disables preservados para RTX 4060 (desktop fixo, sem Optimus).
    # TODO: migrar para feature gpu.prime quando existir.
    hardware.nvidia = {
      prime = {
        sync.enable = lib.mkForce false;
        offload.enable = lib.mkForce false;
      };
    };

    # SSH habilitado (portas e settings ficam em rve-compat.nix)
    services.openssh = {
      enable = true;
      ports = [ 2224 ];
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        X11Forwarding = false;
        AllowTcpForwarding = "yes"; # Necessário para SSH Tunneling (VNC)
        LogLevel = "VERBOSE";
      };
    };

    # Tailscale
    services.tailscale.enable = true;

    # Firewall base: confia no túnel Tailscale
    networking.firewall.trustedInterfaces = [ "tailscale0" ];

    # Hardening: Fail2Ban para proteger o SSH exposto
    services.fail2ban = {
      enable = true;
      maxretry = 4;
      bantime = "1h";
      ignoreIP = [
        "127.0.0.1/8"
        "10.0.0.0/8"
        "192.168.0.0/16"
        "100.64.0.0/10" # Tailscale CGNAT
      ];

      jails.sshd.settings = {
        enabled = true;
        port = "2224";
        backend = "systemd";
        mode = "aggressive";
        findtime = "10m";
        maxretry = 4;
        bantime = "1h";
      };
    };

    # Sudo sem senha para wheel (host single-user)
    security.sudo.wheelNeedsPassword = false;

    # Branding
    kryonix.branding = {
      enable = true;
      prettyName = "Kryonix Glacier";
      edition = "Server/Workstation";
    };

    # Pacotes base de diagnóstico e operação
    # (git, curl, wget, vim, htop já estão em rve-compat.nix — não duplicar)
    environment.systemPackages = with pkgs; [
      efibootmgr
    ];
  };
}
