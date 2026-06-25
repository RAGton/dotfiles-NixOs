# TODO: Módulo legado. Será removido após unificação completa das features.
# A implementação real foi movida para modules/nixos/features/development.nix.
{
  imports = [
    ../modules/nixos/features/development.nix
  ];
}
