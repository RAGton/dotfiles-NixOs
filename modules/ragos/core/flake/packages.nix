/*
  Pacotes e devShells públicos do flake.
  Expõe a CLI canônica `ragc` e a ISO quando o sistema atual suporta Linux.
*/
{
  self,
  pkgs,
  ragosParams,
}:
let
  clientTargetFromChannel = channel: if channel == "lab" then "desktop-lab" else "desktop-generic";
  brandingAssets = ragosParams.brandingAssets or (import ./branding-assets.nix);
  ragc = import ../ragc/default.nix {
    inherit pkgs;
    ragosServerIp = ragosParams.serverIp;
    ragosHttpPort = ragosParams.httpPort;
    ragosDefaultClientTarget = clientTargetFromChannel (ragosParams.clientDefaultChannel or "generic");
  };
  ragos = import ../server/ragos-cli.nix {
    inherit pkgs;
  };
  ragosPlymouthTheme = pkgs.callPackage ../themes/plymouth/ragos { };
  ragosSddmTheme = pkgs.callPackage ../themes/sddm/ragos-control {
    ragosBrandingAssets = brandingAssets;
  };
  plasmaBrandingPackages = pkgs.callPackage ../themes/plasma {
    ragosBrandingAssets = brandingAssets;
  };
  ragosPlasmaTheme = plasmaBrandingPackages.ragosPlasmaBranding;
  ragosPlasmaKdeStoreBundles = plasmaBrandingPackages.ragosPlasmaKdeStoreBundles;
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
        printf "ERROR: execute 'nix run .#repo-hygiene-lint' a partir da raiz do checkout do RAGOS.\n" >&2
        exit 2
      fi

      exec ${pkgs.bash}/bin/bash ./scripts/tests/lint-repo-organization.sh "$@"
    '';
  };
in
{
  packages = {
    inherit ragc ragos;
    "ragos-plymouth-theme" = ragosPlymouthTheme;
    "ragos-sddm-theme" = ragosSddmTheme;
    "ragos-plasma-theme" = ragosPlasmaTheme;
    "ragos-plasma-kde-store-bundles" = ragosPlasmaKdeStoreBundles;
    "repo-hygiene-lint" = repoHygieneLint;
    default = ragc;
  }
  // (pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
    ragos-client-desktop-generic =
      self.nixosConfigurations.ragos-client-dev-desktop-generic.config.system.build.toplevel;
    ragos-client-desktop-lab =
      self.nixosConfigurations.ragos-client-dev-desktop-lab.config.system.build.toplevel;
    ragos-client-hyperv-debug =
      self.nixosConfigurations.ragos-client-dev-hyperv-debug.config.system.build.toplevel;
    ragos-client-rescue-minimal =
      self.nixosConfigurations.ragos-client-dev-rescue-minimal.config.system.build.toplevel;

    ragos-client-official-desktop-generic =
      self.nixosConfigurations.ragos-client-desktop-generic.config.system.build.toplevel;
    ragos-client-official-desktop-lab =
      self.nixosConfigurations.ragos-client-desktop-lab.config.system.build.toplevel;
    ragos-client-official-hyperv-debug =
      self.nixosConfigurations.ragos-client-hyperv-debug.config.system.build.toplevel;
    ragos-client-official-rescue-minimal =
      self.nixosConfigurations.ragos-client-rescue-minimal.config.system.build.toplevel;
  })
  // (pkgs.lib.optionalAttrs (pkgs.stdenv.isLinux && self.nixosConfigurations ? ragos-iso) {
    ragos-iso = self.nixosConfigurations.ragos-iso.config.system.build.isoImage;
  });

  formatter = pkgs.nixfmt-rfc-style;

  devShells.default = pkgs.mkShell {
    buildInputs = with pkgs; [
      git
      nixfmt-rfc-style
      nixos-rebuild
      ripgrep
      treefmt
      ragc
    ];
  };
}
