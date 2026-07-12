{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.kryonix.kernel.cachyos;
in {
  options.kryonix.kernel.cachyos = {
    enable = lib.mkEnableOption "Enable CachyOS kernel";

    pkg = lib.mkOption {
      type = lib.types.str;
      default = "linux-cachyos-lts-lto";
      description = "O nome exato do pacote do kernel no flake nix-cachyos-kernel";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (final: prev:
        let
          cachyosInput = inputs.kryonix.inputs.nix-cachyos-kernel or inputs.nix-cachyos-kernel;
          zfsPkg = builtins.replaceStrings ["linux-cachyos"] ["zfs-cachyos"] cfg.pkg;
        in {
          cachyos-kernel = cachyosInput.packages.${pkgs.system}.${cfg.pkg} or cachyosInput.packages.${pkgs.system}."linux-cachyos-lts-lto";
          zfs_cachyos = cachyosInput.packages.${pkgs.system}.${zfsPkg} or cachyosInput.packages.${pkgs.system}."zfs-cachyos-lts-lto";
        }
      )
    ];

    boot.kernelPackages = (pkgs.linuxPackagesFor pkgs.cachyos-kernel).extend (
      final: prev: {
        zfs = pkgs.zfs_cachyos;
      }
    );

    # Força o módulo ZFS a ser exatamente o que foi compilado com o kernel cachyos
    boot.zfs.package = lib.mkDefault pkgs.zfs_cachyos;
  };
}
