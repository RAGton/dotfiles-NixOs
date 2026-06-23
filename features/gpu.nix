# =============================================================================
# Feature: Intel GPU / iGPU (kryonix.features.gpu.intel)
#
# O que é:
# - Feature declarativa para Intel GPU / iGPU.
# - Ativa drivers, VA-API, Quick Sync, diagnostic tools.
# - Opt-in via kryonix.features.gpu.intel.enable = true.
#
# Por quê:
# - Centraliza a configuração Intel GPU que estava hardcoded nos hosts.
# - Mantém hosts finos e focados em decisões (enable = true), não em lógica.
# - Padroniza drivers e variáveis de ambiente.
#
# Como usar:
#   kryonix.features.gpu.intel.enable = true;
#
# Subopções:
#   enable32Bit     → ativa suporte 32-bit (Steam/Wine)
#   vaapi.enable    → drivers VA-API (intel-media-driver, libvdpau-va-gl)
#   quickSync.enable → Intel Quick Sync / oneVPL
#   compute.enable  → Intel compute runtime (OpenCL) — desligado por padrão
#   diagnostics.enable → ferramentas de diagnóstico
#   forceIHD        → força LIBVA_DRIVER_NAME = "iHD"
#   legacyVaapi.enable → driver VA-API legado (intel-vaapi-driver) — desligado
#   videoDrivers    → drivers Xorg/Wayland (default: modesetting)
#
# Riscos:
# - legacyVaapi pode conflitar com iHD moderno
# - compute.enable adiciona dependências pesadas
# =============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kryonix.features.gpu.intel;
in
{
  options.kryonix.features.gpu.intel = {
    enable = lib.mkEnableOption "Intel GPU / iGPU support (drivers, VA-API, Quick Sync, diagnostics)";

    enable32Bit = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable 32-bit graphics stack for Steam/Wine compatibility.";
    };

    vaapi = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Intel VA-API userspace drivers (intel-media-driver, libvdpau-va-gl).";
      };
    };

    quickSync = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Intel Quick Sync / oneVPL runtime where available.";
      };
    };

    compute = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Intel compute/OpenCL runtime (intel-compute-runtime). Disabled by default to keep the base lighter.";
      };
    };

    diagnostics = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install diagnostic tools such as vainfo, intel-gpu-tools, vulkan-tools and mesa-demos.";
      };
    };

    forceIHD = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Prefer the modern Intel iHD VA-API driver via LIBVA_DRIVER_NAME environment variable.";
    };

    legacyVaapi = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable legacy intel-vaapi-driver for older Intel GPUs. Off by default because it is not the modern path.";
      };
    };

    videoDrivers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "modesetting" ];
      description = "Xorg/Wayland compatible Intel display driver list.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Xorg/Wayland display driver
    services.xserver.videoDrivers = lib.mkDefault cfg.videoDrivers;

    # Graphics stack
    hardware.graphics = {
      enable = lib.mkDefault true;
      enable32Bit = lib.mkDefault cfg.enable32Bit;

      extraPackages = with pkgs; lib.flatten [
        (lib.optionals cfg.vaapi.enable [
          intel-media-driver
          libvdpau-va-gl
        ])

        (lib.optionals cfg.quickSync.enable [
          vpl-gpu-rt
        ])

        (lib.optionals cfg.compute.enable [
          intel-compute-runtime
        ])

        (lib.optionals cfg.legacyVaapi.enable [
          intel-vaapi-driver
        ])
      ];
    };

    # Environment: force iHD VA-API driver
    environment.sessionVariables = lib.mkIf cfg.forceIHD {
      LIBVA_DRIVER_NAME = lib.mkDefault "iHD";
    };

    # Diagnostic tools
    environment.systemPackages = with pkgs;
      lib.optionals cfg.diagnostics.enable (lib.flatten [
        (lib.optional (lib.hasAttrByPath [ "libva-utils" ] pkgs) pkgs.libva-utils)
        (lib.optional (lib.hasAttrByPath [ "intel-gpu-tools" ] pkgs) pkgs.intel-gpu-tools)
        (lib.optional (lib.hasAttrByPath [ "vulkan-tools" ] pkgs) pkgs.vulkan-tools)
        (lib.optional (lib.hasAttrByPath [ "mesa-demos" ] pkgs) pkgs.mesa-demos)
      ]);
  };
}