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
      # Valor concreto: evita que `offlineMode` seja resolvido via _module.args
      # (que exige `config`) quando usado em `imports` de hosts/iso → recursão.
      offlineMode = false;
    };
    modules = [ ../../hosts/iso ];
  };
}
