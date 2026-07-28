{ inputs, lib }:
let
  formattingCheck =
    lib.checkPkgs.runCommand "nixfmt-check"
      {
        nativeBuildInputs = [
          lib.checkPkgs.findutils
          lib.checkPkgs.nixfmt
        ];
        src = ../.;
      }
      ''
        cd "$src"
        ${lib.checkPkgs.findutils}/bin/find . -type f -name '*.nix' -print0 \
          | ${lib.checkPkgs.findutils}/bin/xargs -0 ${lib.checkPkgs.nixfmt}/bin/nixfmt --check
        mkdir -p "$out"
      '';

  cliHelpCheck =
    lib.checkPkgs.runCommand "kryonix-cli-help-check"
      {
        nativeBuildInputs = [
          lib.checkPkgs.jq
          inputs.self.packages.x86_64-linux.kryx
        ];
      }
      ''
        export KRYONIX_BRAIN_API="http://invalid-runtime-dependency"
        export HOME=$TMPDIR
        KRYONIX=${inputs.self.packages.x86_64-linux.kryx}/bin/kryx

        echo "Validando help global..."
        $KRYONIX --help > /dev/null


        mkdir -p "$out"
      '';
in
{
  x86_64-linux = {
    formatting = formattingCheck;
    cli-help = cliHelpCheck;

    "nixos-iso-eval" =
      lib.checkPkgs.writeText "nixos-iso-drvpath" "${lib.stripContext inputs.self.nixosConfigurations.iso.config.system.build.toplevel.drvPath}\n";

    # PR 1 do Kryonix AI Server: garante que 10 cenarios das assertions
    # do modulo `kryonix.services.aiServer` se mantem compativeis. Se
    # algum cenario divergir, o `assert evaluated.allPass;` no tests.nix
    # faz o derivation falhar e `nix flake check` reporta.
    #
    # Ver: modules/nixos/services/ai-server/tests.nix
    "ai-server-options" = import ../modules/nixos/services/ai-server/tests.nix {
      inherit lib;
      checkPkgs = lib.checkPkgs;
      self = inputs.self;
      # lib customizada do motor nao expoe evalModules; injete o canonico.
      nixpkgsLib = inputs.nixpkgs.lib;
    };
  };
}
