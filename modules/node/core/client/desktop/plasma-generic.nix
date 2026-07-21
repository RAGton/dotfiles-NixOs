{ ... }:

{
  imports = [
    ./plasma6.nix
    ./branding.nix
  ];

  node.desktop.allowXWayland = true;
}
