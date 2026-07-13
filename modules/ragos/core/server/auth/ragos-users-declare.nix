{ ragosAdminUser, ragosAdminUid, ... }:

# Declaração de usuários para o módulo ragos-users-btrfs.nix.
# Habilite este módulo em server.nix juntamente com ragos-users-btrfs.nix.
# O usuário e UID são lidos do flake.nix (ragosParams).
{
  ragos.users = {
    enable = true;

    users = {
      ${ragosAdminUser} = {
        uid = ragosAdminUid;
        quotaGB = 20;
      };
    };
  };
}
