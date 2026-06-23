# =============================================================================
# Feature: CPU Intel/AMD (kryonix.features.cpu.*)
#
# O que é:
# - Feature declarativa para CPUs Intel e AMD.
# - Ativa microcode, diagnóstico e opções de tuning seguras.
# - Opt-in via kryonix.features.cpu.intel.enable ou .amd.enable.
#
# Por quê:
# - Centraliza configuração de CPU que estava dispersa entre nixos-hardware
#   e hosts individuais.
# - Mantém hosts finos e focados em decisões (enable = true), não em lógica.
#
# Como usar:
#   kryonix.features.cpu.intel.enable = true;
#   kryonix.features.cpu.amd.enable = true;
#
# Riscos:
# - Microcode pode ter efeitos colaterais em hardware muito antigo.
# - AMD P-State pode causar instabilidade em alguns kernels/BIOS.
# =============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kryonix.features.cpu;
in
{
  options.kryonix.features.cpu = {
    intel = {
      enable = lib.mkEnableOption "Intel CPU support (microcode, diagnostics, thermald)";

      microcode = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable Intel CPU microcode updates.";
        };
      };

      thermald = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable thermald thermal daemon on Intel CPUs. Disabled by default to avoid conflicting with host power policy.";
        };
      };

      diagnostics = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Install CPU diagnostic tools (pciutils, lshw, dmidecode, cpupower).";
        };
      };
    };

    amd = {
      enable = lib.mkEnableOption "AMD CPU support (microcode, diagnostics, P-State)";

      microcode = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable AMD CPU microcode updates.";
        };
      };

      pstate = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable AMD P-State kernel parameter. Disabled by default because behavior depends on CPU/kernel/BIOS.";
        };

        mode = lib.mkOption {
          type = lib.types.enum [ "active" "passive" "guided" ];
          default = "active";
          description = "AMD P-State mode when pstate.enable is true.";
        };
      };

      diagnostics = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Install CPU diagnostic tools (pciutils, lshw, dmidecode, cpupower, zenmonitor).";
        };
      };
    };
  };

  config = lib.mkMerge [
    # Intel CPU
    (lib.mkIf cfg.intel.enable {
      hardware.cpu.intel.updateMicrocode = lib.mkDefault cfg.intel.microcode.enable;

      services.thermald = lib.mkIf cfg.intel.thermald.enable {
        enable = true;
      };

      environment.systemPackages = with pkgs;
        lib.optionals cfg.intel.diagnostics.enable (lib.flatten [
          (lib.optional (lib.hasAttrByPath [ "pciutils" ] pkgs) pciutils)
          (lib.optional (lib.hasAttrByPath [ "usbutils" ] pkgs) usbutils)
          (lib.optional (lib.hasAttrByPath [ "lshw" ] pkgs) lshw)
          (lib.optional (lib.hasAttrByPath [ "dmidecode" ] pkgs) dmidecode)
          (lib.optional (lib.hasAttrByPath [ "linuxPackages" ] pkgs && pkgs.linuxPackages ? cpupower) pkgs.linuxPackages.cpupower)
        ]);
    })

    # AMD CPU
    (lib.mkIf cfg.amd.enable {
      hardware.cpu.amd.updateMicrocode = lib.mkDefault cfg.amd.microcode.enable;

      boot.kernelParams = lib.mkIf cfg.amd.pstate.enable [
        "amd_pstate=${cfg.amd.pstate.mode}"
      ];

      environment.systemPackages = with pkgs;
        lib.optionals cfg.amd.diagnostics.enable (lib.flatten [
          (lib.optional (lib.hasAttrByPath [ "pciutils" ] pkgs) pciutils)
          (lib.optional (lib.hasAttrByPath [ "usbutils" ] pkgs) usbutils)
          (lib.optional (lib.hasAttrByPath [ "lshw" ] pkgs) lshw)
          (lib.optional (lib.hasAttrByPath [ "dmidecode" ] pkgs) dmidecode)
          (lib.optional (lib.hasAttrByPath [ "linuxPackages" ] pkgs && pkgs.linuxPackages ? cpupower) pkgs.linuxPackages.cpupower)
          (lib.optional (lib.hasAttrByPath [ "zenmonitor" ] pkgs) zenmonitor)
        ]);
    })
  ];
}