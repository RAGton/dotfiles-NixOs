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
    kryonixInstaller = pkgs.callPackage ../packages/kryonix-installer.nix { };
    kryonixLlamaCppCuda = pkgs.callPackage ../packages/kryonix-llama-cpp-cuda.nix { };
    kora = pkgs.callPackage ../packages/kora.nix { };
    kryonixOptimizer = pkgs.callPackage ../packages/kryonix-optimizer { };
    kryonixCli = pkgs.callPackage ../packages/kryonix-cli.nix {
      inherit kryonixHome kora;
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
    kora = kora;
    kryonix-optimizer = kryonixOptimizer;
    "deno-cache-only" = denoCacheOnly;
  }
)
