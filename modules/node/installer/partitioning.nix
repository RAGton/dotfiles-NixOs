# Biblioteca declarativa (referência) de layout de discos do instalador NODE.
# Este arquivo existe para manter o layout auditável e versionado.
# A execução (parted/mkfs/btrfs subvolume) fica em `installer/bin/node-install`.
{
  singleDisk = {
    filesystem = "btrfs";
    subvolumes = {
      "@root" = "/";
      "@nix" = "/nix";
      "@srv" = "/srv";
      "@node_homes" = "/srv/data/home";
      "@node_images" = "/srv/data/images";
      "@node_snapshots" = "/srv/data/snapshots";
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
        "@node_homes" = "/srv/data/home";
        "@node_images" = "/srv/data/images";
        "@node_snapshots" = "/srv/data/snapshots";
      };
    };
  };
}
