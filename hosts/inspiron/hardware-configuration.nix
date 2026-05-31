# Hardware configuration para o host "inspiron"
#
# Layout do NVMe (ADATA 512GB) — gerenciado pelo disko (disks.nix):
#   part1 = EFI (1G)          → /boot             UUID: 4509-A31C
#   part2 = swap (16G)                             UUID: 8b6df5d3-9f96-4b48-8877-36bbe2642d21
#   part3 = btrfs SISTEMA     → subvolumes abaixo  UUID: 9d31dd94-2893-4c2a-bc47-bb2c4a8d55fc
#   part4 = btrfs HOME        → @home              UUID: a8b6794b-b034-44e6-8cd7-ef4013cb7fdd
#
# SDA (Kingston 240G) — NÃO gerenciado pelo disko:
#   part1 = btrfs RAG-DATA    → /RAG-DATA (NUNCA FORMATAR)
#
# NOTA: O disko gera automaticamente entradas fileSystems para o NVMe usando
#       PARTLABEL (ex: disk-nvme0n1-system). Essas entradas são sobrescritas
#       abaixo com UUID para maior confiabilidade no boot.
#       UUIDs confirmados via `lsblk -f` no Live ISO.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ "i915" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # ─── NVMe p1: EFI — override com UUID (substitui PARTLABEL do disko) ───
  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-uuid/4509-A31C";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  # ─── NVMe p3: SISTEMA — overrides com UUID (substitui PARTLABEL do disko) ───
  # UUID: 9d31dd94-2893-4c2a-bc47-bb2c4a8d55fc
  # Todos os subvolumes abaixo compartilham o mesmo UUID de filesystem btrfs.
  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-uuid/9d31dd94-2893-4c2a-bc47-bb2c4a8d55fc";
    fsType = "btrfs";
    options = [
      "subvol=@"
      "compress=zstd"
      "noatime"
    ];
  };
  fileSystems."/nix" = lib.mkForce {
    device = "/dev/disk/by-uuid/9d31dd94-2893-4c2a-bc47-bb2c4a8d55fc";
    fsType = "btrfs";
    options = [
      "subvol=@nix"
      "compress=zstd"
      "noatime"
    ];
  };
  fileSystems."/var/log" = lib.mkForce {
    device = "/dev/disk/by-uuid/9d31dd94-2893-4c2a-bc47-bb2c4a8d55fc";
    fsType = "btrfs";
    options = [
      "subvol=@log"
      "compress=zstd"
      "noatime"
    ];
  };
  fileSystems."/var/cache" = lib.mkForce {
    device = "/dev/disk/by-uuid/9d31dd94-2893-4c2a-bc47-bb2c4a8d55fc";
    fsType = "btrfs";
    options = [
      "subvol=@cache"
      "compress=zstd"
      "noatime"
    ];
  };
  fileSystems."/var/lib/containers" = lib.mkForce {
    device = "/dev/disk/by-uuid/9d31dd94-2893-4c2a-bc47-bb2c4a8d55fc";
    fsType = "btrfs";
    options = [
      "subvol=@containers"
      "compress=zstd"
      "noatime"
    ];
  };
  fileSystems."/var/lib/libvirt" = lib.mkForce {
    device = "/dev/disk/by-uuid/9d31dd94-2893-4c2a-bc47-bb2c4a8d55fc";
    fsType = "btrfs";
    options = [
      "subvol=@libvirt"
      "compress=zstd"
      "noatime"
    ];
  };
  fileSystems."/.snapshots" = lib.mkForce {
    device = "/dev/disk/by-uuid/9d31dd94-2893-4c2a-bc47-bb2c4a8d55fc";
    fsType = "btrfs";
    options = [
      "subvol=@snapshots"
      "compress=zstd"
      "noatime"
    ];
  };
  fileSystems."/persist" = lib.mkForce {
    device = "/dev/disk/by-uuid/9d31dd94-2893-4c2a-bc47-bb2c4a8d55fc";
    fsType = "btrfs";
    options = [
      "subvol=@persist"
      "compress=zstd"
      "noatime"
    ];
  };
  fileSystems."/tmp" = lib.mkForce {
    device = "/dev/disk/by-uuid/9d31dd94-2893-4c2a-bc47-bb2c4a8d55fc";
    fsType = "btrfs";
    options = [
      "subvol=@tmp"
      "compress=zstd"
      "noatime"
    ];
  };

  # ─── NVMe p4: HOME — override com UUID (substitui PARTLABEL do disko) ───
  fileSystems."/home" = lib.mkForce {
    device = "/dev/disk/by-uuid/a8b6794b-b034-44e6-8cd7-ef4013cb7fdd";
    fsType = "btrfs";
    options = [
      "subvol=@home"
      "compress=zstd"
      "noatime"
      "autodefrag"
    ];
  };

  # ─── NVMe p2: swap — override com UUID (substitui PARTLABEL do disko) ───
  swapDevices = lib.mkForce [
    { device = "/dev/disk/by-uuid/8b6df5d3-9f96-4b48-8877-36bbe2642d21"; }
  ];

  # ─── SDA: RAG-DATA (NÃO gerenciado pelo disko) ───
  fileSystems."/RAG-DATA" = {
    device = "/dev/disk/by-id/ata-KINGSTON_SA400S37240G_50026B7785682AEA-part1";
    fsType = "btrfs";
    options = [
      "compress=zstd"
      "noatime"
    ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
