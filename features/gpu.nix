# =============================================================================
# Feature: GPU (Intel, NVIDIA, CUDA) — kryonix.features.gpu.*
#
# O que é:
# - Feature declarativa para GPUs Intel, NVIDIA e CUDA.
# - Cada GPU é opt-in via kryonix.features.gpu.{intel,nvidia}.enable = true.
# - CUDA requer NVIDIA habilitado (assertion).
#
# Por quê:
# - Centraliza a configuração de GPU que estava hardcoded nos hosts.
# - Mantém hosts finos e focados em decisões (enable = true), não em lógica.
#
# Como usar:
#   kryonix.features.gpu.intel.enable = true;
#   kryonix.features.gpu.nvidia.enable = true;
#   kryonix.features.gpu.cuda.enable = true;  # requer nvidia enable
#
# Subopções por GPU:
#   intel.*     → ver GPU_INTEL.md
#   nvidia.*    → ver GPU_NVIDIA.md
#   cuda.*      → ver GPU_NVIDIA.md
# =============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kryonix.features.gpu;
in
{
  options.kryonix.features.gpu = {
    # =====================================================================
    # Intel GPU
    # =====================================================================
    intel = {
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

    # =====================================================================
    # NVIDIA GPU
    # =====================================================================
    nvidia = {
      enable = lib.mkEnableOption "NVIDIA GPU driver support (proprietary driver, modesetting, nvidia-settings)";

      open = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Use NVIDIA open kernel modules when supported.
          Recommended for RTX 20/GTX 16 series or newer.
          Set to false for older GPUs or if the open module is unstable.
        '';
      };

      modesetting = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable NVIDIA kernel modesetting. Recommended for Wayland.";
        };
      };

      powerManagement = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable NVIDIA power management. Disabled by default to avoid suspend/resume regressions.";
        };

        finegrained = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable fine-grained NVIDIA power management. Useful mostly for laptops; disabled by default.";
        };
      };

      nvidiaSettings = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Install nvidia-settings GUI tool.";
        };
      };

      persistenced = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Enable NVIDIA persistence daemon (nvidia-persistenced).
            Useful for compute/server workloads to keep GPU initialized.
            Disabled by default for desktop use.
            TODO: implementar hardware.nvidia.nvidiaPersistenced quando confirmado no nixpkgs 26.05.
          '';
        };
      };

      package = lib.mkOption {
        type = lib.types.enum [
          "default"
          "stable"
          "production"
          "beta"
        ];
        default = "default";
        description = ''
          NVIDIA driver package branch.
          - "default": let NixOS choose the default.
          - "stable": nvidiaPackages.stable (recommended for production).
          - "production": nvidiaPackages.production (long-term branch).
          - "beta": nvidiaPackages.beta (new features, unstable).
        '';
      };

      diagnostics = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Install NVIDIA diagnostic tools (nvidia-smi, nvtop, vulkan-tools).";
        };
      };
    };

    # =====================================================================
    # CUDA / AI compute
    # =====================================================================
    cuda = {
      enable = lib.mkEnableOption "NVIDIA CUDA / AI compute support";

      toolkit = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Install CUDA toolkit packages (nvcc, cudart). Disabled by default to avoid heavy closures.";
        };
      };

      cudaSupport = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Enable nixpkgs.config.cudaSupport globally. This rebuilds many
            packages with CUDA support. Heavy and potentially expensive;
            disabled by default. Prefer per-package CUDA overrides when possible.
          '';
        };
      };

      binaryCache = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the NixOS CUDA binary cache to avoid local CUDA builds.";
        };
      };

      diagnostics = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Install CUDA/NVIDIA validation tools where available.";
        };
      };
    };
  };

  config = lib.mkMerge [
    # ===================================================================
    # Intel GPU implementation
    # ===================================================================
    (lib.mkIf cfg.intel.enable {
      services.xserver.videoDrivers = lib.mkDefault cfg.intel.videoDrivers;

      hardware.graphics = {
        enable = lib.mkDefault true;
        enable32Bit = lib.mkDefault cfg.intel.enable32Bit;

        extraPackages =
          with pkgs;
          lib.flatten [
            (lib.optionals cfg.intel.vaapi.enable [
              intel-media-driver
              libvdpau-va-gl
            ])

            (lib.optionals cfg.intel.quickSync.enable [
              vpl-gpu-rt
            ])

            (lib.optionals cfg.intel.compute.enable [
              intel-compute-runtime
            ])

            (lib.optionals cfg.intel.legacyVaapi.enable [
              intel-vaapi-driver
            ])
          ];
      };

      environment.sessionVariables = lib.mkIf cfg.intel.forceIHD {
        LIBVA_DRIVER_NAME = lib.mkDefault "iHD";
      };

      environment.systemPackages =
        with pkgs;
        lib.optionals cfg.intel.diagnostics.enable (
          lib.flatten [
            (lib.optional (lib.hasAttrByPath [ "libva-utils" ] pkgs) pkgs.libva-utils)
            (lib.optional (lib.hasAttrByPath [ "intel-gpu-tools" ] pkgs) pkgs.intel-gpu-tools)
            (lib.optional (lib.hasAttrByPath [ "vulkan-tools" ] pkgs) pkgs.vulkan-tools)
            (lib.optional (lib.hasAttrByPath [ "mesa-demos" ] pkgs) pkgs.mesa-demos)
          ]
        );
    })

    # ===================================================================
    # NVIDIA GPU implementation
    # ===================================================================
    (lib.mkIf cfg.nvidia.enable {
      # Graphics base
      hardware.graphics = {
        enable = lib.mkDefault true;
        enable32Bit = lib.mkDefault true;
      };

      # Xorg display driver
      services.xserver.videoDrivers = lib.mkDefault [ "nvidia" ];

      # NVIDIA driver settings
      hardware.nvidia = {
        open = lib.mkDefault cfg.nvidia.open;
        modesetting.enable = lib.mkDefault cfg.nvidia.modesetting.enable;

        powerManagement.enable = lib.mkDefault cfg.nvidia.powerManagement.enable;
        powerManagement.finegrained = lib.mkDefault cfg.nvidia.powerManagement.finegrained;

        nvidiaSettings = lib.mkDefault cfg.nvidia.nvidiaSettings.enable;
      };

      # Enable Xorg for nvidia (required for driver init)
      services.xserver.enable = lib.mkDefault true;

      # NVIDIA diagnostic tools
      environment.systemPackages =
        with pkgs;
        lib.optionals cfg.nvidia.diagnostics.enable (
          lib.flatten [
            (lib.optional (pkgs ? nvidia-settings) nvidia-settings)
            (lib.optional (lib.hasAttrByPath [ "nvtopPackages" "nvidia" ] pkgs) pkgs.nvtopPackages.nvidia)
            (lib.optional (lib.hasAttrByPath [ "vulkan-tools" ] pkgs) pkgs.vulkan-tools)
            (lib.optional (lib.hasAttrByPath [ "mesa-demos" ] pkgs) pkgs.mesa-demos)
            (lib.optional (lib.hasAttrByPath [ "pciutils" ] pkgs) pciutils)
          ]
        );

      # NVIDIA driver package selection (only if not "default")
      # Uses mkDefault to coexist with profiles that set package directly.
      hardware.nvidia.package = lib.mkIf (cfg.nvidia.package != "default") (
        lib.mkDefault (
          let
            packages = config.boot.kernelPackages.nvidiaPackages;
          in
          if cfg.nvidia.package == "stable" then
            packages.stable
          else if cfg.nvidia.package == "production" then
            packages.production
          else if cfg.nvidia.package == "beta" then
            packages.beta
          else
            packages.stable
        )
      );
    })

    # ===================================================================
    # CUDA implementation
    # ===================================================================
    (lib.mkIf cfg.cuda.enable {
      # CUDA requires NVIDIA
      assertions = [
        {
          assertion = cfg.nvidia.enable;
          message = "kryonix.features.gpu.cuda.enable requires kryonix.features.gpu.nvidia.enable = true.";
        }
      ];

      # NixOS CUDA binary cache
      nix.settings = lib.mkIf cfg.cuda.binaryCache.enable {
        substituters = lib.mkAfter [
          "https://cache.nixos-cuda.org"
        ];
        trusted-public-keys = lib.mkAfter [
          "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
        ];
      };

      # Global cudaSupport (heavy, disabled by default)
      nixpkgs.config.cudaSupport = lib.mkIf cfg.cuda.cudaSupport.enable true;

      # CUDA toolkit packages
      environment.systemPackages =
        lib.optionals cfg.cuda.diagnostics.enable (
          lib.optional (lib.hasAttrByPath [ "pciutils" ] pkgs) pkgs.pciutils
        )
        ++ lib.optionals cfg.cuda.toolkit.enable (
          lib.flatten [
            (lib.optional (lib.hasAttrByPath [ "cudaPackages" "cuda_nvcc" ] pkgs) pkgs.cudaPackages.cuda_nvcc)
            (lib.optional (lib.hasAttrByPath [
              "cudaPackages"
              "cuda_cudart"
            ] pkgs) pkgs.cudaPackages.cuda_cudart)
          ]
        );
    })
  ];
}
