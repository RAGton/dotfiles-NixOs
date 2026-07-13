{ ... }:

{
  imports = [
    ./plasma6.nix
    ./branding.nix
  ];

  ragos.desktop.allowXWayland = false;
}
