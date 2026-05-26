{ inputs, users }:
let
  supportedSystems = [
    "x86_64-linux"
    "aarch64-linux"
  ];
  forAllSystems = inputs.nixpkgs.lib.genAttrs supportedSystems;

  stripContext = builtins.unsafeDiscardStringContext;

  mkDenoCacheOnly =
    pkgs:
    pkgs.writeShellApplication {
      name = "deno";
      runtimeInputs = [ pkgs.nix ];
      text = ''
        set -euo pipefail

        # Use the stable input here because the current unstable Deno may
        # miss cache.nixos.org and try to build rusty-v8/V8 locally.
        exec nix shell \
          --inputs-from path:${inputs.self} \
          --no-write-lock-file \
          --option max-jobs 0 \
          --option builders "" \
          nixpkgs-stable#deno \
          --command deno "$@"
      '';
    };

  # Load Overlays for mkHomePkgs
  repoOverlays = import ../overlays { inherit inputs; };

  mkHomePkgs =
    system:
    import inputs.nixpkgs {
      inherit system;
      overlays = [
        repoOverlays.stable-packages
        repoOverlays.atlauncher-api-user-agent-workaround
        repoOverlays.xeus-cling-no-checks
        repoOverlays.codex-overlay
        repoOverlays.kryonix-installer-tools
      ];
      config.allowUnfree = true;
    };

  checkPkgs = import inputs.nixpkgs {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };

  mkNixosConfiguration =
    hostname: username:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs hostname;
        outputs = inputs.self.outputs;
        isDarwin = false;
        userConfig = users.${username};
        nixosModules = "${inputs.self}/modules/nixos";
      };
      modules = [
        ../hosts/${hostname}
        ../hosts/common
      ];
    };

  mkHomeConfiguration =
    system: username: hostname:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = mkHomePkgs system;
      extraSpecialArgs = {
        inherit inputs;
        outputs = inputs.self.outputs;
        userConfig = users.${username};
        nhModules = "${inputs.self}/modules/home-manager";
      };
      modules = [ ../home/${username}/${hostname} ];
    };

in
{
  inherit
    supportedSystems
    forAllSystems
    stripContext
    mkDenoCacheOnly
    mkHomePkgs
    checkPkgs
    mkNixosConfiguration
    mkHomeConfiguration
    repoOverlays
    ;
}
