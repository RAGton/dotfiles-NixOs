{
  config,
  lib,
  pkgs,
  ragosServerIp ? null,
  ...
}:

let
  cfg = config.ragos.auth.homeAfterLogin;

  defaultServer = if ragosServerIp != null && ragosServerIp != "" then ragosServerIp else "127.0.0.1";

  mountOptions =
    cfg.mountOptions ++ lib.optionals cfg.kerberos.enable [ "sec=${cfg.kerberos.securityFlavor}" ];

  mountOptionsStr = lib.concatStringsSep "," mountOptions;
in
{
  options.ragos.auth.homeAfterLogin = {
    enable = lib.mkEnableOption "Mount user homes after login via pam_mount";

    server = lib.mkOption {
      type = lib.types.str;
      default = defaultServer;
      example = "192.168.100.10";
      description = "NFS server address used to mount user home directories.";
    };

    remoteBase = lib.mkOption {
      type = lib.types.str;
      default = "/srv/data/home";
      description = "Remote base path on the NFS server where homes live.";
    };

    mountBase = lib.mkOption {
      type = lib.types.str;
      default = "/home";
      description = "Local base path for mounted homes.";
    };

    fsType = lib.mkOption {
      type = lib.types.str;
      default = "nfs4";
      description = "Filesystem type passed to pam_mount (e.g. nfs, nfs4).";
    };

    mountOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "rw"
        "noatime"
        "nconnect=4"
        "vers=4.2"
        "hard"
        "timeo=600"
        "retrans=5"
        "proto=tcp"
        "nodev"
        "nosuid"
      ];
      description = "Mount options used by pam_mount for home volumes.";
    };

    kerberos = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Kerberos security flavors (sec=krb5*) for NFS home mounts.";
      };

      securityFlavor = lib.mkOption {
        type = lib.types.str;
        default = "krb5p";
        description = "NFS Kerberos security flavor to use (krb5, krb5i, krb5p).";
      };
    };

    idmapDomain = lib.mkOption {
      type = lib.types.str;
      default = "ragos.local";
      description = "Dominio NFSv4 usado para o mapeamento de ownership da home persistente.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.mountBase} 0755 root root -"
    ];

    security.pam.mount.enable = true;
    security.pam.mount.additionalSearchPaths = [ pkgs.nfs-utils ];
    security.pam.mount.debugLevel =
      if lib.attrByPath [ "ragos" "profile" "bootVerbose" ] false config then 1 else 0;
    security.pam.mount.logoutWait = 2000000;
    security.pam.mount.logoutTerm = true;
    security.pam.mount.extraVolumes = [
      ''<volume user="*" fstype="${cfg.fsType}" server="${cfg.server}" path="${cfg.remoteBase}/%(USER)" mountpoint="${cfg.mountBase}/%(USER)" options="${mountOptionsStr}" mkmountpoint="1" />''
    ];

    services.nfs.idmapd.settings = lib.mkMerge [
      {
        General.Verbosity = 0;
        Mapping = {
          Nobody-User = "nobody";
          Nobody-Group = "nogroup";
        };
      }
      (lib.mkIf (cfg.idmapDomain != "") {
        General.Domain = cfg.idmapDomain;
      })
    ];
  };
}
