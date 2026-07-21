# ─────────────────────────────────────────────────────────────────────────────
# GROUP STORAGE MOUNTS — Montagem de storage compartilhado de grupos
#
# Configuração:
#   - Monta /srv/data/storage/<group> via NFS em /home/<usuario>/Setores/<group>
#   - Grupo "admin" é montado automaticamente em todos os clientes
#   - Outros grupos podem ser adicionados conforme necessário
#   - Permissões preservadas do servidor (owner:group + bits)
#
# Storage Layout no Cliente:
#   /home/<usuario>/Setores/
#   ├── admin/        (automático, admin GID 3000)
#   └── <outros>/     (conforme adicionado via CLI)
# ─────────────────────────────────────────────────────────────────────────────

{
  config,
  lib,
  pkgs,
  nodeServerIp ? null,
  ...
}:

let
  cfg = config.node.auth.groupStorageMount;

  defaultServer = if nodeServerIp != null && nodeServerIp != "" then nodeServerIp else "127.0.0.1";

  mountOptions =
    cfg.mountOptions ++ lib.optionals cfg.kerberos.enable [ "sec=${cfg.kerberos.securityFlavor}" ];

  mountOptionsStr = lib.concatStringsSep "," mountOptions;

  # Gerar volume entries para pam_mount
  generateVolumes =
    groups:
    map (group: ''
      <volume user="*" 
              fstype="${cfg.fsType}" 
              server="${cfg.server}" 
              path="${cfg.remoteBase}/${group}" 
              mountpoint="${cfg.mountBase}/${group}" 
              options="${mountOptionsStr}" 
              mkmountpoint="1" />
    '') groups;
in
{
  options.node.auth.groupStorageMount = {
    enable = lib.mkEnableOption "Mount group storage directories after login";

    server = lib.mkOption {
      type = lib.types.str;
      default = defaultServer;
      example = "192.168.100.10";
      description = "NFS server address for group storage mounts.";
    };

    remoteBase = lib.mkOption {
      type = lib.types.str;
      default = "/srv/data/storage";
      description = "Remote base path on NFS server where group storage lives.";
    };

    mountBase = lib.mkOption {
      type = lib.types.str;
      default = "/home/%(USER)/Setores";
      description = "Local base path for group storage mounts inside the mounted home.";
    };

    fsType = lib.mkOption {
      type = lib.types.str;
      default = "nfs4";
      description = "Filesystem type (nfs or nfs4).";
    };

    mountOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "ro" # Read-only by default
        "noatime"
        "nconnect=2"
        "vers=4.2"
        "hard"
        "timeo=600"
        "retrans=3"
        "proto=tcp"
        "nodev"
        "nosuid"
        "noexec" # Prevent execution from storage
      ];
      description = "Mount options for group storage (typically read-only).";
    };

    groups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "admin" ];
      example = [
        "admin"
        "teaching"
        "staff"
      ];
      description = "List of group names to mount. 'admin' is always mounted.";
    };

    kerberos = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Kerberos security for NFS mounts.";
      };

      securityFlavor = lib.mkOption {
        type = lib.types.str;
        default = "krb5p";
        description = "NFS Kerberos security flavor (krb5, krb5i, krb5p).";
      };
    };

    idmapDomain = lib.mkOption {
      type = lib.types.str;
      default = "node.local";
      description = "NFSv4 identity mapping domain.";
    };
  };

  config = lib.mkIf cfg.enable {
    # -----------------------------------------------------------------------
    # Create mount base directory
    # -----------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d ${cfg.mountBase} 0755 root root -"
    ];

    # -----------------------------------------------------------------------
    # Ensure admin group exists locally (GID 3000)
    # -----------------------------------------------------------------------
    users.groups.admin = {
      gid = 3000;
    };

    # -----------------------------------------------------------------------
    # Enable pam_mount and add group storage volumes
    # -----------------------------------------------------------------------
    security.pam.mount.enable = true;
    security.pam.mount.additionalSearchPaths = [ pkgs.nfs-utils ];
    security.pam.mount.debugLevel =
      if lib.attrByPath [ "node" "profile" "bootVerbose" ] false config then 1 else 0;
    security.pam.mount.logoutWait = 2000000;
    security.pam.mount.logoutTerm = true;
    security.pam.mount.extraVolumes = generateVolumes cfg.groups;

    # -----------------------------------------------------------------------
    # NFSv4 ID mapping
    # -----------------------------------------------------------------------
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
