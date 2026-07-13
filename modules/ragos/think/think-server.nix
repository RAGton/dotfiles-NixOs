{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ragos.thinkServer;
in
{
  options.ragos.thinkServer = {
    enable = lib.mkEnableOption "RAGOS Think Server";

    hostId = lib.mkOption {
      type = lib.types.str;
      description = "Host ID unico para o ZFS, obrigatorio para importar pools.";
      example = "8425e349";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelPackages = pkgs.linuxPackages_6_12;
    boot.supportedFilesystems = [ "zfs" ];

    networking.hostId = cfg.hostId;

    assertions = [
      {
        assertion = config.boot.kernelPackages.kernel.version == pkgs.linuxPackages_6_12.kernel.version;
        message = "RAGOS Think Server requer Kernel 6.12 para compatibilidade com ZFS.";
      }
    ];

    fileSystems = {
      "/srv/data/home" = {
        device = "zroot/srv-data/home";
        fsType = "zfs";
      };

      "/srv/data/images" = {
        device = "zroot/srv-data/images";
        fsType = "zfs";
      };

      "/srv/data/snapshots" = {
        device = "zroot/srv-data/snapshots";
        fsType = "zfs";
      };

      "/srv/data/storage" = {
        device = "zroot/srv-data/storage";
        fsType = "zfs";
      };
    };
  };
}
