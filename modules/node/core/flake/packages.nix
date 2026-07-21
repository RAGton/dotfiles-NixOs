/*
  Pacotes e devShells públicos do flake.
  Expõe a CLI canônica `knyc` e a ISO quando o sistema atual suporta Linux.
*/
{
  self,
  pkgs,
  nodeParams,
}:
let
  clientTargetFromChannel = channel: if channel == "lab" then "desktop-lab" else "desktop-generic";
  brandingAssets = nodeParams.brandingAssets or (import ./branding-assets.nix);
  knyc = import ../knyc/default.nix {
    inherit pkgs;
    nodeServerIp = nodeParams.serverIp;
    nodeHttpPort = nodeParams.httpPort;
    nodeDefaultClientTarget = clientTargetFromChannel (nodeParams.clientDefaultChannel or "generic");
  };
  node = import ../server/node-cli.nix {
    inherit pkgs;
  };
  repoHygieneLint = pkgs.writeShellApplication {
    name = "repo-hygiene-lint";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      findutils
      git
      gnused
      ripgrep
    ];
    text = ''
      if [[ ! -f ./scripts/tests/lint-repo-organization.sh ]]; then
        printf "ERROR: execute 'nix run .#repo-hygiene-lint' a partir da raiz do checkout do NODE.\n" >&2
        exit 2
      fi

      exec ${pkgs.bash}/bin/bash ./scripts/tests/lint-repo-organization.sh "$@"
    '';
  };
in
{
  packages = {
    inherit knyc node;
    "repo-hygiene-lint" = repoHygieneLint;
    default = knyc;
  }
  // (pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
    node-client-desktop-generic =
      self.nixosConfigurations.node-client-dev-desktop-generic.config.system.build.toplevel;
    node-client-desktop-lab =
      self.nixosConfigurations.node-client-dev-desktop-lab.config.system.build.toplevel;
    node-client-hyperv-debug =
      self.nixosConfigurations.node-client-dev-hyperv-debug.config.system.build.toplevel;
    node-client-rescue-minimal =
      self.nixosConfigurations.node-client-dev-rescue-minimal.config.system.build.toplevel;

    node-client-official-desktop-generic =
      self.nixosConfigurations.node-client-desktop-generic.config.system.build.toplevel;
    node-client-official-desktop-lab =
      self.nixosConfigurations.node-client-desktop-lab.config.system.build.toplevel;
    node-client-official-hyperv-debug =
      self.nixosConfigurations.node-client-hyperv-debug.config.system.build.toplevel;
    node-client-official-rescue-minimal =
      self.nixosConfigurations.node-client-rescue-minimal.config.system.build.toplevel;
  })
  // (pkgs.lib.optionalAttrs (pkgs.stdenv.isLinux && self.nixosConfigurations ? node-iso) {
    node-iso = self.nixosConfigurations.node-iso.config.system.build.isoImage;
  });

  formatter = pkgs.nixfmt-rfc-style;

  devShells.default = pkgs.mkShell {
    buildInputs = with pkgs; [
      git
      nixfmt-rfc-style
      nixos-rebuild
      ripgrep
      treefmt
      knyc
    ];
  };
}
