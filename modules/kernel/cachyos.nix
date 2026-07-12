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
      (final: prev: {
        # Adiciona o zfs_cachyos do input de terceiros se existir, ou do nix-cachyos-kernel
        # Como xddxdd providencia pacotes no topo do flake:
        cachyos-kernel = inputs.nix-cachyos-kernel.packages.${pkgs.system}."linux_cachyos_${cfg.variant}_${cfg.optimization}" or inputs.nix-cachyos-kernel.packages.${pkgs.system}.linux_cachyos;
        zfs_cachyos = inputs.nix-cachyos-kernel.packages.${pkgs.system}."linux_cachyos_${cfg.variant}_${cfg.optimization}_zfs" or inputs.nix-cachyos-kernel.packages.${pkgs.system}.linux_cachyos_zfs;
      })
    ];

    boot.kernelPackages = pkgs.cachyos-kernel;

    # Força o módulo ZFS a ser exatamente o que foi compilado com o kernel cachyos
    boot.zfs.package = lib.mkDefault config.boot.kernelPackages.zfs_cachyos;
  };
}
