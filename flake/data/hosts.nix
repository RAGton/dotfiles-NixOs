{ inputs, lib }:
{
  inspiron = lib.mkNixosConfiguration "inspiron" "rocha";
  inspiron-nina = lib.mkNixosConfiguration "inspiron-nina" "nina";
  glacier = lib.mkNixosConfiguration "glacier" "rocha";

  glacier-live = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      outputs = inputs.self.outputs;
    };
    modules = [ ../../hosts/glacier/live.nix ];
  };

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
