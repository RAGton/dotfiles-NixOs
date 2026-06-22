{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./shell.nix
    ./terminal.nix
    ./editor.nix
    ./browser.nix
    ./ai.nix
    ./dev.nix
    ./desktop.nix
    ./obsidian.nix
  ];
}
