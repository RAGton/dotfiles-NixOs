{
  config,
  lib,
  pkgs,
  ...
}:

let
  resolvedHostProfile =
    if config.ragos.profile.name != "" then config.ragos.profile.name else "desktop-generic";
  ragosSddmTheme = pkgs.callPackage ./ragos-control {
    hostLabel = if config.networking.hostName != "" then config.networking.hostName else "ragos-client";
    profileLabel = resolvedHostProfile;
  };
in
{
  config = lib.mkIf config.services.displayManager.sddm.enable {
    environment.systemPackages = [ ragosSddmTheme ];

    # O nome do tema e mais robusto do que depender do caminho absoluto no
    # Current do SDDM, desde que o pacote esteja no system profile.
    services.displayManager.sddm.theme = "ragos-control";
  };
}
