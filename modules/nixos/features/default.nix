{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./schema.nix
    ./removed-options.nix
    ./registry.nix
    ./network.nix
    ./desktop.nix
    ./development.nix
    ./virtualization.nix
    ./gaming.nix
    ./server.nix
    ./ai.nix
    ./storage.nix
    ./security.nix
    ./remote.nix
    ./observability.nix
    ./mcp.nix
    ./browser-automation.nix
    ./acme.nix
  ];
}
