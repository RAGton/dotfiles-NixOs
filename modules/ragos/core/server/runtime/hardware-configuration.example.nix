/*
  PLACEHOLDER (GERADO PELO INSTALADOR)

  Este arquivo e usado apenas como fallback quando
  `/var/lib/ragos/runtime/hardware-configuration.nix` ainda nao existe localmente.

  O arquivo real vive fora do checkout Git operacional.
*/
{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.loader.grub.enable = lib.mkDefault false;

  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
  };

  # Politica operacional:
  # - swap no Tier 0
  # - preferir particao swap dedicada
  # - swapfile em / como fallback aceitavel
  # - 8 GiB: host pequeno
  # - 16 GiB: host com build/rebuild/testes
  # - 32 GiB: host mais carregado
  swapDevices = lib.mkDefault [ ];
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
