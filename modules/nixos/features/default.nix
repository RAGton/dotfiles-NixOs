{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./schema.nix
    ./registry.nix
    ./desktop.nix
    ./development.nix
    ./virtualization.nix
    ./gaming.nix
    ./server.nix
    ./network.nix
    ./ai.nix
    ./storage.nix
    ./security.nix
    ./remote.nix
    ./observability.nix
    ./mcp.nix
    ./browser-automation.nix
  ];
}
