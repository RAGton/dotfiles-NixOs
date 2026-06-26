{ inputs, lib }:
lib.forAllSystems (
  system:
  let
    pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
    kryonixHome = pkgs.callPackage ../packages/kryonix-home.nix {
      kryonixHomeSrc = inputs.kryonix-home;
    };
    kryonixBrainLightrag = pkgs.callPackage ../packages/kryonix-brain-lightrag.nix {
      kryonix-brain-lightrag-src = inputs.kryonix-brain-lightrag;
    };
    kryonixHardwareProbe = pkgs.callPackage ../packages/kryonix-hardware-probe.nix { };
    kryonixDiskPlanner = pkgs.callPackage ../packages/kryonix-disk-planner.nix { };
    kryonixInstaller = inputs.kryonix-installer.packages.${system}.kryonix-installer;
    kryonixLlamaCppCuda = pkgs.callPackage ../packages/kryonix-llama-cpp-cuda.nix { };
    kryonixOptimizer = pkgs.callPackage ../packages/kryonix-optimizer { };
    kryonixBranding = pkgs.callPackage ../packages/kryonix-branding.nix { };
    kryonixPlasmaTheme = pkgs.callPackage ../packages/kryonix-plasma-theme.nix {
      inherit kryonixBranding;
    };
    kryonixSddmTheme = pkgs.callPackage ../packages/kryonix-sddm-theme.nix {
      inherit kryonixBranding;
    };
    kryonixWallpapers = pkgs.callPackage ../packages/kryonix-wallpapers.nix { };
    kryonixCli = pkgs.callPackage ../packages/kryonix-cli.nix {
      inherit kryonixHome;
      kryonix-hardware-probe = kryonixHardwareProbe;
      kryonix-disk-planner = kryonixDiskPlanner;
      kryonix-installer = kryonixInstaller;
    };
    denoCacheOnly = lib.mkDenoCacheOnly pkgs;
  in
  {
    default = kryonixCli;
    kryonix = kryonixCli;
    kryonix-home = kryonixHome;
    kryonix-brain-lightrag = kryonixBrainLightrag;
    kryonix-hardware-probe = kryonixHardwareProbe;
    kryonix-disk-planner = kryonixDiskPlanner;
    kryonix-installer = kryonixInstaller;
    kryonix-llama-cpp-cuda = kryonixLlamaCppCuda;
    kryonix-optimizer = kryonixOptimizer;
    kryonix-branding = kryonixBranding;
    kryonix-plasma-theme = kryonixPlasmaTheme;
    kryonix-sddm-theme = kryonixSddmTheme;
    kryonix-wallpapers = kryonixWallpapers;
    "deno-cache-only" = denoCacheOnly;
  }
)
