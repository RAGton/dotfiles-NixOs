{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./desktop.nix
    ./gamer.nix
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
