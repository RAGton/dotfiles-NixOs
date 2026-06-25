# TODO: Módulo legado. Será removido após unificação completa das features.
# A implementação real foi movida para modules/nixos/features/virtualization.nix.
{
  imports = [
    ../modules/nixos/features/virtualization.nix
  ];
}
