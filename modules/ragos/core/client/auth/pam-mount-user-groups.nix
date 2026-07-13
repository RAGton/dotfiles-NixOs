{
  config,
  lib,
  pkgs,
  ragosServerIp ? null,
  ...
}:

let
  cfg = config.ragos.auth.pamMountUserGroups;

  defaultServer = if ragosServerIp != null && ragosServerIp != "" then ragosServerIp else "127.0.0.1";

  mountOptions =
    cfg.mountOptions ++ lib.optionals cfg.kerberos.enable [ "sec=${cfg.kerberos.securityFlavor}" ];

  mountOptionsStr = lib.concatStringsSep "," mountOptions;

  ignoredGroupsRegex = lib.concatStringsSep "|" (map lib.escapeRegex cfg.ignoredGroups);

  pamUserSectorMounts = pkgs.writeShellScriptBin "ragos-user-sector-mounts" ''
    set -euo pipefail

    pam_user="''${PAM_USER:-}"
    pam_type="''${PAM_TYPE:-open_session}"
    ragos_server="${cfg.server}"
    ragos_storage_remote="${cfg.remoteBase}"
    ragos_sectors_dir_name="${cfg.sectorsDirName}"
    mount_options="${mountOptionsStr}"
    home_wait_attempts="${toString cfg.homeWaitAttempts}"
    home_wait_sleep="${cfg.homeWaitSleepSeconds}"
    ignored_groups_regex='${ignoredGroupsRegex}'

    [[ -n "$pam_user" ]] || exit 0

    log_info() {
      logger -t ragos-user-sector-mounts -p user.info "[$pam_user][$pam_type] $*"
    }

    log_error() {
      logger -t ragos-user-sector-mounts -p user.err "[$pam_user][$pam_type] $*"
    }

    user_home_from_passwd() {
      getent passwd "$pam_user" | cut -d: -f6
    }

    primary_group_name() {
      id -gn "$pam_user"
    }

    should_mount_group() {
      local group_name="$1"

      [[ -n "$group_name" ]] || return 1
      [[ "$group_name" != "$pam_user" ]] || return 1

      if [[ -n "$ignored_groups_regex" ]] && [[ "$group_name" =~ ^($ignored_groups_regex)$ ]]; then
        return 1
      fi

      return 0
    }

    wait_for_home_mount() {
      local user_home="$1"
      local attempt=1

      while (( attempt <= home_wait_attempts )); do
        if [[ -d "$user_home" ]] && mountpoint -q "$user_home" 2>/dev/null; then
          return 0
        fi

        sleep "$home_wait_sleep"
        attempt=$((attempt + 1))
      done

      return 1
    }

    ensure_sectors_base() {
      local user_home="$1"
      local sectors_base="$user_home/$ragos_sectors_dir_name"
      local primary_group

      primary_group="$(primary_group_name)"
      install -d -m 0750 -o "$pam_user" -g "$primary_group" "$sectors_base"
      printf '%s\n' "$sectors_base"
    }

    mount_user_groups() {
      local user_home="$1"
      local sectors_base primary_group group_name mount_point

      sectors_base="$(ensure_sectors_base "$user_home")"
      primary_group="$(primary_group_name)"

      for group_name in $(id -Gn "$pam_user"); do
        if ! should_mount_group "$group_name"; then
          continue
        fi

        mount_point="$sectors_base/$group_name"
        install -d -m 0750 -o "$pam_user" -g "$primary_group" "$mount_point"

        if mountpoint -q "$mount_point" 2>/dev/null; then
          log_info "mount ja presente em $mount_point"
          continue
        fi

        if mount -t nfs4 \
          -o "$mount_options" \
          "$ragos_server:$ragos_storage_remote/$group_name" \
          "$mount_point" 2>/dev/null; then
          log_info "setor montado em $mount_point"
        else
          log_error "falha ao montar grupo $group_name em $mount_point"
        fi
      done
    }

    umount_user_groups() {
      local user_home="$1"
      local sectors_base mount_point

      sectors_base="$user_home/$ragos_sectors_dir_name"
      [[ -d "$sectors_base" ]] || exit 0

      while IFS= read -r mount_point; do
        [[ -n "$mount_point" ]] || continue
        if umount "$mount_point" 2>/dev/null; then
          log_info "setor desmontado em $mount_point"
        fi
      done < <(find "$sectors_base" -mindepth 1 -maxdepth 1 -type d | sort -r)
    }

    user_home="$(user_home_from_passwd)"
    [[ -n "$user_home" ]] || exit 0

    case "$pam_type" in
      open_session)
        if ! wait_for_home_mount "$user_home"; then
          log_error "home ainda nao esta montada em $user_home; setores nao serao montados"
          exit 0
        fi

        mount_user_groups "$user_home"
        ;;
      close_session)
        umount_user_groups "$user_home"
        ;;
      *)
        exit 0
        ;;
    esac
  '';
in
{
  options.ragos.auth.pamMountUserGroups = {
    enable = lib.mkEnableOption "Mount user sectors inside the mounted home after a real login";

    server = lib.mkOption {
      type = lib.types.str;
      default = defaultServer;
      example = "192.168.100.10";
      description = "NFS server address for sector storage mounts.";
    };

    remoteBase = lib.mkOption {
      type = lib.types.str;
      default = "/srv/data/storage";
      description = "Remote base path on the NFS server where sector storage lives.";
    };

    sectorsDirName = lib.mkOption {
      type = lib.types.str;
      default = "Setores";
      description = "Stable directory created inside the user's home to expose mounted sectors.";
    };

    ignoredGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "audio"
        "nogroup"
        "root"
        "users"
        "video"
        "wheel"
      ];
      description = "Local groups that should never be translated into sector mounts.";
    };

    homeWaitAttempts = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "How many times the PAM hook waits for /home/<user> to become a real mount before giving up.";
    };

    homeWaitSleepSeconds = lib.mkOption {
      type = lib.types.str;
      default = "0.2";
      description = "Sleep interval between home-mount checks.";
    };

    mountOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "rw"
        "noatime"
        "nconnect=2"
        "vers=4.2"
        "hard"
        "timeo=600"
        "retrans=3"
        "proto=tcp"
        "nodev"
        "nosuid"
      ];
      description = "Mount options for sector storage mounts.";
    };

    kerberos = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Kerberos security for NFS sector mounts.";
      };

      securityFlavor = lib.mkOption {
        type = lib.types.str;
        default = "krb5p";
        description = "NFS Kerberos security flavor (krb5, krb5i, krb5p).";
      };
    };

    idmapDomain = lib.mkOption {
      type = lib.types.str;
      default = "ragos.local";
      description = "NFSv4 identity mapping domain.";
    };
  };

  config = lib.mkIf cfg.enable {
    security.pam.services.login.rules.session.ragosUserSectorMounts = {
      order = config.security.pam.services.login.rules.session.mount.order + 10;
      control = "optional";
      modulePath = "${config.security.pam.package}/lib/security/pam_exec.so";
      args = [ "${pamUserSectorMounts}/bin/ragos-user-sector-mounts" ];
    };

    security.pam.services.sddm.rules.session.ragosUserSectorMounts = {
      order = config.security.pam.services.sddm.rules.session.mount.order + 10;
      control = "optional";
      modulePath = "${config.security.pam.package}/lib/security/pam_exec.so";
      args = [ "${pamUserSectorMounts}/bin/ragos-user-sector-mounts" ];
    };

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

    environment.systemPackages = [
      pamUserSectorMounts
    ];
  };
}
