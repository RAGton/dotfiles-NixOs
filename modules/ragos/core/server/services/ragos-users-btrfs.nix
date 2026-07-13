{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ragos.users;
in
{
  options.ragos.users = {
    enable = lib.mkEnableOption "RAGOS user management with BTRFS quotas";

    basePath = lib.mkOption {
      type = lib.types.str;
      default = "/srv/nfs/home";
      description = "Base path for user home directories";
    };

    users = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            uid = lib.mkOption {
              type = lib.types.int;
              description = "User UID";
            };

            quotaGB = lib.mkOption {
              type = lib.types.int;
              description = "Quota in GB (BTRFS qgroup)";
            };
          };
        }
      );
      default = { };
      description = "RAGOS users with BTRFS quota";
    };
  };

  config = lib.mkIf cfg.enable {

    # Garante que quotas BTRFS estejam ativas
    systemd.services.btrfs-qgroups = {
      description = "Enable BTRFS qgroups";
      wantedBy = [ "multi-user.target" ];
      serviceConfig.ExecStart = "${pkgs.btrfs-progs}/bin/btrfs quota enable /srv";
    };

    # Criação de usuários do sistema
    users.users = lib.mapAttrs (name: user: {
      isNormalUser = true;
      uid = user.uid;
      home = "${cfg.basePath}/${name}";
      createHome = false;
    }) cfg.users;

    # Criação de subvolumes + quotas
    system.activationScripts.ragosUsers = lib.stringAfter [ "var" ] (
      lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: user: ''
          echo ">> RAGOS: preparando home de ${name}"

          if [ ! -d "${cfg.basePath}/${name}" ]; then
            ${pkgs.btrfs-progs}/bin/btrfs subvolume create ${cfg.basePath}/${name}
            chown ${name}:users ${cfg.basePath}/${name}
          fi

          qgroup=$(${pkgs.btrfs-progs}/bin/btrfs qgroup show -f ${cfg.basePath}/${name} | awk 'NR==3 {print $1}')

          ${pkgs.btrfs-progs}/bin/btrfs qgroup limit \
            ${toString user.quotaGB}G \
            $qgroup \
            ${cfg.basePath}/${name}
        '') cfg.users
      )
    );
  };
}
