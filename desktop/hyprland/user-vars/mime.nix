# =============================================================================
# user-vars/mime.nix — Preferências de aplicativos do usuário
#
# Associações MIME (qual app abre cada tipo de arquivo) e configurações
# de apps via dconf. Ambas são específicas por usuário — não vão em core/.
#
# Para substituir uma associação no host: use lib.mkForce nas defaultApplications
# do host config (ver exemplo em home/rocha/glacier/default.nix).
# =============================================================================
{ ... }:
{
  imports = [
    ../core/mime.nix
    ../core/dconf.nix
  ];
}
