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
    let
      # Quando usado em repositório downstream, kryonix é um input.
      # Quando usado no próprio kryonix, self é o kryonix.
      kryonixSelf = inputs.kryonix or inputs.self;
    in
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs hostname;
        outputs = inputs.self.outputs;
        isDarwin = false;
        userConfig = users.${username};
        nixosModules = "${kryonixSelf}/modules/nixos";
      };
      modules = [
        # Host: resolvido no repositório CHAMADOR (upstream ou downstream)
        "${inputs.self}/hosts/${hostname}"
        # Base comum: sempre do kryonix (contém nix settings, locale, etc.)
        ../hosts/common
      ];
    };

  mkHomeConfiguration =
    system: username: hostname:
    let
      kryonixSelf = inputs.kryonix or inputs.self;
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = mkHomePkgs system;
      extraSpecialArgs = {
        inherit inputs;
        outputs = inputs.self.outputs;
        userConfig = users.${username};
        nhModules = "${kryonixSelf}/modules/home-manager";
      };
      # Home config: resolvida no repositório CHAMADOR
      modules = [ "${inputs.self}/home/${username}/${hostname}" ];
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
