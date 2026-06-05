{ inputs, lib }:
{
  iso = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      outputs = inputs.self.outputs;
      hostname = "iso";
      isDarwin = false;
      # Externalizado em specialArgs para evitar recursão: hosts/iso/default.nix
      # usa offlineMode no bloco `imports`, que precisa ser avaliado ANTES de
      # `config`. Sem este valor externo o Nix cai em `_module.args.offlineMode`,
      # que depende de `config`, e o ciclo imports → config → _module.args →
      # imports estoura como "infinite recursion". O helper iso.nix passa true
      # quando precisar de modo offline; o resto do mundo usa este default.
      offlineMode = false;
      nixosModules = "${inputs.self}/modules/nixos";
    };
    modules = [ ../../hosts/iso ];
  };
}
