{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./desktop.nix
    ./gaming.nix
    ./server.nix
    ./ai.nix
    ./storage.nix
    ./security.nix
    ./remote.nix
    ./observability.nix
    ./mcp.nix
    ./browser-automation.nix
  ];
}
