{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.kryonix;
in
{
  options.programs.kryonix = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Instala a CLI `kryonix`, usada como fluxo operacional principal do Kryonix.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = import ../../../../packages/kryonix-cli.nix { inherit pkgs; };
      defaultText = lib.literalExpression "import ../../../../packages/kryonix-cli.nix { inherit pkgs; }";
      description = "Pacote da CLI `kryonix` exposto no PATH do sistema.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ];
  };
}
