{
  config,
  pkgs,
  lib,
  ragosAdminUser,
  ragosDataDisk,
  ragosDataFsType ? "btrfs",
  ...
}:

# ─────────────────────────────────────────────────────────────────────────────
# STORAGE — separação entre disco de sistema e disco de dados
#
# Disco de sistema:  /dev/nvme0n1  (NixOS, gerenciado pelo hardware-configuration)
# Disco de dados:    ragosDataDisk (configurado em flake.nix)
#
# Layout BTRFS no disco de dados:
#
#   /srv/data/
#     ├── home/       ← subvol @ragos_homes     (homes NFS dos clientes, rw)
#     ├── images/     ← subvol @ragos_images     (imagens netboot versionadas)
#     │     ├── v20260305-120000/
#     │     │     ├── bzImage
#     │     │     └── initrd
#     │     └── current -> v20260305-120000/     ← symlink: imagem ativa
#     └── snapshots/  ← subvol @ragos_snapshots  (snapshots BTRFS automáticos)
#
# Nginx expõe /srv/data/images via /srv/http/netboot (symlink).
# iPXE aponta para:
#   kernel http://<server>/netboot/current/bzImage
#   initrd http://<server>/netboot/current/initrd
#
# Para rollback:
#   ln -sfn /srv/data/images/<versão> /srv/data/images/current
#
# ─────────────────────────────────────────────────────────────────────────────
#
# PREPARAÇÃO INICIAL DO DISCO (uma vez, antes do primeiro nixos-rebuild):
#
#   mkfs.btrfs -L ragos-data /dev/sdb
#   mount /dev/sdb /mnt
#   btrfs subvolume create /mnt/@ragos_homes
#   btrfs subvolume create /mnt/@ragos_images
#   btrfs subvolume create /mnt/@ragos_snapshots
#   umount /mnt
#
# ─────────────────────────────────────────────────────────────────────────────

let
  usersGroup = "users";
  usersGroupGid = toString config.users.groups.users.gid;
  tier1Requires = [
    "/srv/data"
    "/srv/data/images"
    "/srv/data/home"
    "/srv/data/snapshots"
  ];

  tier1MountChecks =
    if ragosDataFsType == "btrfs" then
      [
        "/srv/data/home"
        "/srv/data/images"
        "/srv/data/snapshots"
      ]
    else
      [
        "/srv/data"
      ];

  tier1ConditionMount = if ragosDataFsType == "btrfs" then "/srv/data/images" else "/srv/data";

  tier1ReadyScript = pkgs.writeShellScript "ragos-tier1-ready" ''
    set -euo pipefail
    ${lib.concatMapStringsSep "\n" (mountPath: ''
      ${pkgs.util-linux}/bin/mountpoint -q ${mountPath} || {
        echo "RAGOS Tier 1 not ready: ${mountPath}" >&2
        exit 1
      }
    '') tier1MountChecks}
  '';

  ensureHomeSkeletonScript = pkgs.writeShellScript "ragos-home-skeleton" ''
    set -euo pipefail

    home_path="$1"
    owner_uid="$2"

    install -d -m 0700 -o "$owner_uid" -g "${usersGroup}" "$home_path"
    install -d -m 0700 -o "$owner_uid" -g "${usersGroup}" "$home_path/.config"
    install -d -m 0700 -o "$owner_uid" -g "${usersGroup}" "$home_path/.cache"
    install -d -m 0700 -o "$owner_uid" -g "${usersGroup}" "$home_path/.local"
    install -d -m 0700 -o "$owner_uid" -g "${usersGroup}" "$home_path/.local/share"

    for dir in Desktop Documents Downloads Pictures Videos Music; do
      install -d -m 0750 -o "$owner_uid" -g "${usersGroup}" "$home_path/$dir"
    done
  '';

  ensureAdminHomeScript =
    if (ragosAdminUser != "" && ragosAdminUser != null) then
      pkgs.writeShellScript "ragos-ensure-admin-home" ''
        set -euo pipefail

        home_root="/srv/data/home"
        home_path="$home_root/${ragosAdminUser}"
        owner_uid="$(id -u ${ragosAdminUser})"
        migrate_dir=""

        install -d -m 0755 "$home_root"

        if [[ "${ragosDataFsType}" == "btrfs" ]]; then
          if ! ${pkgs.btrfs-progs}/bin/btrfs subvolume show "$home_path" >/dev/null 2>&1; then
            if [[ -e "$home_path" ]]; then
              migrate_dir="$(mktemp -d "$home_root/.migrate-${ragosAdminUser}.XXXXXX")"
              find "$home_path" -mindepth 1 -maxdepth 1 -exec mv -t "$migrate_dir" -- '{}' +
              rm -rf "$home_path"
            fi

            ${pkgs.btrfs-progs}/bin/btrfs subvolume create "$home_path"

            if [[ -n "$migrate_dir" ]]; then
              cp -aT "$migrate_dir" "$home_path"
              rm -rf "$migrate_dir"
            fi
          fi
        else
          install -d -m 0700 "$home_path"
        fi

        chown "$owner_uid:${usersGroupGid}" "$home_path"
        chmod 0700 "$home_path"
        ${ensureHomeSkeletonScript} "$home_path" "$owner_uid"
      ''
    else
      null;

  swapPaths = map (swap: swap.device or "") config.swapDevices;
in
{
  warnings = lib.optional (config.swapDevices == [ ]) ''
    RAGOS: servidor sem swap configurada. Politica operacional: swap no Tier 0, nunca no Tier 1; 8 GiB para host pequeno, 16 GiB para host com build/rebuild/testes, 32 GiB para host mais carregado.
  '';

  assertions = [
    {
      assertion = !(config.zramSwap.enable && config.swapDevices == [ ]);
      message = "RAGOS: zram nao pode ser o swap principal do servidor.";
    }
    {
      assertion = builtins.all (device: !(lib.hasInfix "/srv/data" device)) swapPaths;
      message = "RAGOS: swap no Tier 1 (/srv/data) e proibido.";
    }
  ];

  zramSwap.enable = lib.mkDefault false;

  # -----------------------------------------------------------------------
  # Montagem do disco de dados
  # - btrfs: subvolumes individuais (home/images/snapshots)
  # - ext4/xfs: monta /srv/data como um único filesystem
  # -----------------------------------------------------------------------
  fileSystems =
    if ragosDataFsType == "btrfs" then
      {
        "/srv/data/home" = lib.mkDefault {
          device = ragosDataDisk;
          fsType = "btrfs";
          options = [
            "subvol=@ragos_homes"
            "compress=zstd"
            "noatime"
          ];
        };

        "/srv/data/images" = lib.mkDefault {
          device = ragosDataDisk;
          fsType = "btrfs";
          options = [
            "subvol=@ragos_images"
            "compress=zstd"
            "noatime"
          ];
        };

        "/srv/data/snapshots" = lib.mkDefault {
          device = ragosDataDisk;
          fsType = "btrfs";
          options = [
            "subvol=@ragos_snapshots"
            "compress=zstd"
            "noatime"
          ];
        };

        "/srv/nfs/nix/store" = {
          device = "/nix/store";
          options = [ "bind" ];
        };

        "/srv/nfs/srv/data/home" = {
          device = "/srv/data/home";
          options = [ "bind" ];
        };
      }
    else
      {
        "/srv/data" = lib.mkDefault {
          device = ragosDataDisk;
          fsType = ragosDataFsType;
          options = [ "noatime" ];
        };

        "/srv/nfs/nix/store" = {
          device = "/nix/store";
          options = [ "bind" ];
        };

        "/srv/nfs/srv/data/home" = {
          device = "/srv/data/home";
          options = [ "bind" ];
        };
      };

  # -----------------------------------------------------------------------
  # Garante que os pontos de montagem existam antes do mount
  # -----------------------------------------------------------------------
  systemd.tmpfiles.rules = [
    "d /srv/data           0755 root root -"
    "d /srv/data/home      0755 root root -"
    "d /srv/data/home/.archive 0750 root root -"
    "d /srv/data/images    0755 root root -"
    "d /srv/dat
    
    
    
    
    
    
    
    
    
    
    
    
    a/snapshots 0755 root root -"
    "d /srv/data/snapshots/users 0750 root root -"
    "d /srv/nfs            0755 root root -"
    "d /srv/nfs/nix        0755 root root -"
    "d /srv/nfs/nix/store  0555 root root -"
    "d /srv/nfs/srv        0755 root root -"
    "d /srv/nfs/srv/data   0755 root root -"
    "d /srv/nfs/srv/data/home 0755 root root -"
    # TFTP ainda fica no sistema (não precisa ser persistente)
    "d /srv/tftp           0755 root root -"
    "d /srv/tftp/EFI/BOOT  0755 root root -"
    # HTTP raiz servida pelo nginx
    "d /srv/http           0755 root root -"
  ];

  system.activationScripts.ragosAdminHome =
    lib.mkIf (ragosAdminUser != "" && ragosAdminUser != null)
      {
        text = ''
          ${ensureAdminHomeScript}
        '';
        deps = [ "specialfs" ];
      };

  # -----------------------------------------------------------------------
  # Symlink: /srv/http/netboot → /srv/data/images
  # Nginx serve /srv/http, então http://server/netboot/current/bzImage
  # aponta para /srv/data/images/current/bzImage
  # -----------------------------------------------------------------------
  system.activationScripts.ragosNetbootLink = {
    text = ''
      mkdir -p /srv/http
      rm -f /srv/http/.netboot.tmp
      ln -s /srv/data/images /srv/http/.netboot.tmp
      mv -Tf /srv/http/.netboot.tmp /srv/http/netboot
    '';
    deps = [ "specialfs" ];
  };

  # -----------------------------------------------------------------------
  # Provisionar BOOTX64.EFI automaticamente (TFTP)
  # Evita depender de script manual após o primeiro nixos-rebuild.
  # -----------------------------------------------------------------------
  system.activationScripts.ragosProvisionTftp = {
    text = ''
      install -d -m 0755 /srv/tftp/EFI/BOOT
      install -m 0644 ${pkgs.ipxe}/ipxe.efi /srv/tftp/EFI/BOOT/BOOTX64.EFI
      install -m 0644 ${../pxe/ipxe/autoexec.ipxe} /srv/tftp/autoexec.ipxe
      install -m 0644 ${../pxe/menus/menu.ipxe} /srv/tftp/menu.ipxe
    '';
    deps = [ "specialfs" ];
  };

  # -----------------------------------------------------------------------
  # Expor scripts iPXE estáticos via HTTP (útil para debug e fallback).
  # Usa paths imutáveis do store em vez de depender do link /srv/ragos.
  # -----------------------------------------------------------------------
  system.activationScripts.ragosExposeIpxe = {
    text = ''
      mkdir -p /srv/http
      rm -f /srv/http/.menu.ipxe.tmp /srv/http/.autoexec.ipxe.tmp
      ln -s ${../pxe/menus/menu.ipxe} /srv/http/.menu.ipxe.tmp
      ln -s ${../pxe/ipxe/autoexec.ipxe} /srv/http/.autoexec.ipxe.tmp
      mv -Tf /srv/http/.menu.ipxe.tmp /srv/http/menu.ipxe
      mv -Tf /srv/http/.autoexec.ipxe.tmp /srv/http/autoexec.ipxe
    '';
    deps = [ "specialfs" ];
  };

  systemd.services.nginx.unitConfig = {
    RequiresMountsFor = lib.concatStringsSep " " tier1Requires;
    ConditionPathIsMountPoint = tier1ConditionMount;
  };
  systemd.services.nginx.serviceConfig.ExecCondition = tier1ReadyScript;

  systemd.services.nfs-server.unitConfig = {
    RequiresMountsFor = lib.concatStringsSep " " tier1Requires;
    ConditionPathIsMountPoint = tier1ConditionMount;
  };
  systemd.services.nfs-server.serviceConfig.ExecCondition = tier1ReadyScript;

  # -----------------------------------------------------------------------
  # BTRFS quotas habilitadas no disco de dados (necessário para qgroups)
  # -----------------------------------------------------------------------
  systemd.services.ragos-btrfs-quota = {
    description = "Enable BTRFS quotas on /srv/data";
    wantedBy = [ "multi-user.target" ];
    after = [ "srv-data-home.mount" ];
    enable = (ragosDataFsType == "btrfs");
    unitConfig = {
      RequiresMountsFor = lib.concatStringsSep " " tier1Requires;
      ConditionPathIsMountPoint = tier1ConditionMount;
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecCondition = tier1ReadyScript;
      ExecStart = "${pkgs.btrfs-progs}/bin/btrfs quota enable /srv/data/home";
    };
  };

  # -----------------------------------------------------------------------
  # Snapshots automáticos diários de /srv/data/home
  # -----------------------------------------------------------------------
  systemd.services.ragos-snapshot = {
    description = "BTRFS snapshot diário de /srv/data/home";
    enable = (ragosDataFsType == "btrfs");
    unitConfig = {
      RequiresMountsFor = lib.concatStringsSep " " tier1Requires;
      ConditionPathIsMountPoint = tier1ConditionMount;
    };
    serviceConfig = {
      Type = "oneshot";
      ExecCondition = tier1ReadyScript;
      ExecStart = pkgs.writeShellScript "ragos-snapshot" ''
        set -euo pipefail
        SNAP_DIR="/srv/data/snapshots"
        SRC="/srv/data/home"
        LABEL="home-$(date +%Y%m%d-%H%M%S)"
        ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r "$SRC" "$SNAP_DIR/$LABEL"
        echo "Snapshot criado: $LABEL"
        # Manter apenas os 7 mais recentes
        ls -1dt "$SNAP_DIR"/home-* | tail -n +8 | xargs -r ${pkgs.btrfs-progs}/bin/btrfs subvolume delete
      '';
    };
  };

  systemd.timers.ragos-snapshot = {
    description = "Snapshot BTRFS diário";
    wantedBy = [ "timers.target" ];
    enable = (ragosDataFsType == "btrfs");
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
