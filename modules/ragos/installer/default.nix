/*
  Composição canônica do instalador.
  A implementação Nix principal permanece em `installer/iso.nix`.
*/
{ ... }:

{
  imports = [
    ./iso.nix
  ];
}
