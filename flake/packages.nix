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
    kryonixInstaller = inputs.kryxd.packages.${system}.kryxd;
    kryonixLlamaCppCuda = pkgs.callPackage ../packages/kryonix-llama-cpp-cuda.nix { };
    kryonixOptimizer = pkgs.callPackage ../packages/kryonix-optimizer { };
    kryonixAssets = inputs.kryonix-assets.packages.${system}.default;
    kryonixBranding = pkgs.callPackage ../packages/kryonix-branding.nix {
      inherit kryonixAssets;
    };
    kryonixWaywallen = pkgs.callPackage ../packages/kryonix-waywallen.nix { };
    kryonixOpenWallpaperEngine = pkgs.callPackage ../packages/kryonix-open-wallpaper-engine.nix { };
    kryonixWaywallenDisplayKde = pkgs.callPackage ../packages/kryonix-waywallen-display-kde.nix { };
    kryonixPlasmaTheme = pkgs.callPackage ../packages/kryonix-plasma-theme.nix {
      inherit kryonixBranding;
    };
    kryonixCarbon = pkgs.callPackage ../packages/themes/kryonix-carbon { };
    kryonixSddmTheme = pkgs.callPackage ../packages/kryonix-sddm-theme.nix {
      inherit kryonixBranding kryonixAssets;
    };
    kryonixDarwinMenu = pkgs.callPackage ../packages/darwinmenu.nix { };
    kryonixWallpapers = pkgs.callPackage ../packages/kryonix-wallpapers.nix {
      inherit kryonixAssets;
    };
    kryx = inputs.kryx-cli.packages.${system}.default;
    denoCacheOnly = lib.mkDenoCacheOnly pkgs;
  in
  {
    default = kryx;
    kryx = kryx;
    kryonix-home = kryonixHome;
    kryonix-brain-lightrag = kryonixBrainLightrag;
    kryonix-hardware-probe = kryonixHardwareProbe;
    kryonix-disk-planner = kryonixDiskPlanner;
    kryxd = kryonixInstaller;
    kryonix-llama-cpp-cuda = kryonixLlamaCppCuda;
    kryonix-optimizer = kryonixOptimizer;
    kryonix-branding = kryonixBranding;
    kryonix-waywallen = kryonixWaywallen;
    kryonix-open-wallpaper-engine = kryonixOpenWallpaperEngine;
    kryonix-waywallen-display-kde = kryonixWaywallenDisplayKde;
    kryonix-plasma-theme = kryonixPlasmaTheme;
    kryonix-carbon = kryonixCarbon;
    kryonix-sddm-theme = kryonixSddmTheme;
    kryonix-darwinmenu = kryonixDarwinMenu;
    kryonix-wallpapers = kryonixWallpapers;
    "deno-cache-only" = denoCacheOnly;
  }
)
