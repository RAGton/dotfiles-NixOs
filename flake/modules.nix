{ self, inputs }:
{
  nixosModules = {
    default = { config, lib, pkgs, ... }: {
      imports = [
        ../lib/options.nix
      ];
    };
  };

  homeManagerModules = {
    default = { config, lib, pkgs, ... }: {
      # Módulo exportado para ser usado em configurações downstream
    };
  };
}
