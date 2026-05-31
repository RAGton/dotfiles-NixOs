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
          inputs.self.packages.x86_64-linux.kryonix
        ];
      }
      ''
        export KRYONIX_BRAIN_API="http://invalid-runtime-dependency"
        export HOME=$TMPDIR

        KRYONIX=${inputs.self.packages.x86_64-linux.kryonix}/bin/kryonix

        echo "Validando help global..."
        $KRYONIX --help > /dev/null

        echo "Validando registry JSON..."
        JSON=$($KRYONIX commands --json)
        echo "$JSON" | ${lib.checkPkgs.jq}/bin/jq . > /dev/null

        echo "Validando comandos individuais..."
        $KRYONIX commands | while read -r cmd; do
          echo "  - $cmd"
          $KRYONIX "$cmd" --help > /dev/null
        done

        mkdir -p "$out"
      '';
in
{
  x86_64-linux = {
    formatting = formattingCheck;
    cli-help = cliHelpCheck;

    "nixos-iso-eval" =
      lib.checkPkgs.writeText "nixos-iso-drvpath" "${lib.stripContext inputs.self.nixosConfigurations.iso.config.system.build.toplevel.drvPath}\n";
  };
}
