# Biblioteca declarativa (referência) de layout de discos do instalador RAGOS.
# Este arquivo existe para manter o layout auditável e versionado.
# A execução (parted/mkfs/btrfs subvolume) fica em `installer/bin/ragos-install`.
{
  singleDisk = {
    filesystem = "btrfs";
    subvolumes = {
      "@root" = "/";
      "@nix" = "/nix";
      "@srv" = "/srv";
      "@ragos_homes" = "/srv/data/home";
      "@ragos_images" = "/srv/data/images";
      "@ragos_snapshots" = "/srv/data/snapshots";
    };
  };

  twoDisks = {
    disk1 = {
      # Sistema (EFI + /)
      filesystem = "ext4-or-btrfs";
    };
    disk2 = {
      mountpoint = "/srv/data";
      filesystem = "btrfs";
      subvolumes = {
        "@ragos_homes" = "/srv/data/home";
        "@ragos_images" = "/srv/data/images";
        "@ragos_snapshots" = "/srv/data/snapshots";
      };
    };
  };
}
