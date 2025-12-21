{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/9b4be4a1-a3e4-4392-bd62-45e08eb10b6a";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/32BA-E33E";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/485598d3-5729-48b2-8fc3-d27ac3d5404b";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd:3" "autodefrag" "noatime" ];
  };


  swapDevices =
    [ { device = "/dev/disk/by-uuid/36589f00-8afe-4388-a313-e6f00e933e4f"; }
    ];

  environment.systemPackages = with pkgs; [
    btrfs-progs
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
