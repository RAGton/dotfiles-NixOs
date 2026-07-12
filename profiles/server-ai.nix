{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.kryonix.profiles.server-ai;
in
{
  options.kryonix.profiles.server-ai = {
    enable = mkEnableOption "Profile de Servidor de IA (Glacier)";
  };

  config = mkIf cfg.enable {
    # Habilita o Brain como servidor
    kryonix.services.brain = {
      enable = true;
      role = "server";
      ollama.enable = true;
      ollama.acceleration = "cuda";
      storagePath = "/var/lib/kryonix/brain/storage";
      vaultPath = "/var/lib/kryonix/vault";
    };

    # SSH para gerenciamento remoto
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
      openFirewall = true;
    };

    # Tailscale é essencial para o ecossistema distribuído
    services.kryonix.tailscale = {
      enable = true;
      autoconnect = true;
    };

    # Otimização de performance para servidor de alta carga
    powerManagement.cpuFreqGovernor = "performance";

    # Monitoramento básico
    environment.systemPackages = with pkgs; [
      htop
      iotop
    ];

    # Firewall restrito: Apenas LAN e Tailscale
    networking.firewall = {
      enable = true;
      trustedInterfaces = [ "tailscale0" "br-glacier-lan" ];
    };
  };
}
