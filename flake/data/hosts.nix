{ inputs, lib }:
{
  iso = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      outputs = inputs.self.outputs;
      hostname = "iso";
      isDarwin = false;
      nixosModules = "${inputs.self}/modules/nixos";
    };
    modules = [ ../../hosts/iso ];
  };
}
