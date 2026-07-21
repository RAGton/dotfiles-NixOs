{ ... }:

{
  imports = [
    ./base.nix
    ./modules/network.nix
    ./modules/boot/observability.nix
  ];
}
