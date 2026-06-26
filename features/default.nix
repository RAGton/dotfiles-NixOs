{ lib, ... }:
{
  warnings = [
    "kryonix legacy features/default.nix is deprecated; use modules/nixos/features/default.nix and kryonix.features.* instead."
  ];
}
