{ config, lib, pkgs, ... }:
let cfg = config.kryonix.features.server; in
{
  options.kryonix.features.server = {
    containers.enable = lib.mkEnableOption "Container runtime (Podman)";
    database.enable = lib.mkEnableOption "Database services";
    reverseProxy.enable = lib.mkEnableOption "Reverse proxy (Traefik/Nginx)";
    backups.enable = lib.mkEnableOption "Backup services";
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.containers.enable {
      virtualisation.containers.enable = true;
      virtualisation.podman = {
        enable = true;
        dockerCompat = true;
        defaultNetwork.settings.dns_enabled = true;
      };
    })
  ];
}
