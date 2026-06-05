{
  offlineMode ? false,
}:
let
  flake = builtins.getFlake (toString ./.);
  # Re-evaluate with the desired offlineMode
  # We use the same logic as flake/data/hosts.nix but with the injected arg
  pkgs = flake.inputs.nixpkgs;
  system = "x86_64-linux";
in
(pkgs.lib.nixosSystem {
  inherit system;
  specialArgs = {
    inherit offlineMode;
    inputs = flake.inputs;
    outputs = flake.outputs;
    hostname = "iso";
    isDarwin = false;
    nixosModules = "${flake.inputs.self}/modules/nixos";
  };
  modules = [ ./hosts/iso ];
}).config.system.build.isoImage
