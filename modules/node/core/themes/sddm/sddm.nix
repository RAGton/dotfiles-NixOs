{
  config,
  lib,
  pkgs,
  ...
}:

let
  resolvedHostProfile =
    if config.node.profile.name != "" then config.node.profile.name else "desktop-generic";
  nodeSddmTheme = pkgs.callPackage ./node-control {
    hostLabel = if config.networking.hostName != "" then config.networking.hostName else "node-client";
    profileLabel = resolvedHostProfile;
  };
in
{
  config = lib.mkIf config.services.displayManager.sddm.enable {
    environment.systemPackages = [ nodeSddmTheme ];

    # O nome do tema e mais robusto do que depender do caminho absoluto no
    # Current do SDDM, desde que o pacote esteja no system profile.
    services.displayManager.sddm.theme = "node-control";
  };
}
