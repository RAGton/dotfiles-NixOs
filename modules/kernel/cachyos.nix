{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.kryonix.kernel.cachyos;
in
{
  options.kryonix.kernel.cachyos = {
    enable = lib.mkEnableOption "Enable CachyOS kernel";
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (inputs.kryonix.inputs.nix-cachyos-kernel or inputs.nix-cachyos-kernel).overlays.default
    ];

    boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-lts-lto;
    boot.zfs.package = lib.mkDefault pkgs.cachyosKernels.linuxPackages-cachyos-lts-lto.zfs_cachyos;
  };
}
