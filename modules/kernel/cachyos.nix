{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.kryonix.kernel.cachyos;
in {
  options.kryonix.kernel.cachyos = {
    enable = lib.mkEnableOption "Enable CachyOS kernel";

    variant = lib.mkOption {
      type = lib.types.enum [ "default" "lto" ];
      default = "lto";
      description = "CachyOS kernel variant to use.";
    };

    optimization = lib.mkOption {
      type = lib.types.str;
      default = "zen4";
      description = "CPU optimization architecture for the kernel.";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (final: prev:
        let
          cachyosInput = inputs.kryonix.inputs.nix-cachyos-kernel or inputs.nix-cachyos-kernel;
        in {
          cachyos-kernel = cachyosInput.packages.${pkgs.system}."linux_cachyos_${cfg.variant}_${cfg.optimization}" or cachyosInput.packages.${pkgs.system}.linux_cachyos;
          zfs_cachyos = cachyosInput.packages.${pkgs.system}."linux_cachyos_${cfg.variant}_${cfg.optimization}_zfs" or cachyosInput.packages.${pkgs.system}.linux_cachyos_zfs;
        }
      )
    ];

    boot.kernelPackages = pkgs.cachyos-kernel;

    # Força o módulo ZFS a ser exatamente o que foi compilado com o kernel cachyos
    boot.zfs.package = lib.mkDefault config.boot.kernelPackages.zfs_cachyos;
  };
}
