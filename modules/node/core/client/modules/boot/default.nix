{ ... }:

{
  imports = [
    ./filesystem-overlay.nix
    ./initrd-network.nix
    ./network-stage2.nix
    ./observability.nix
  ];
}
