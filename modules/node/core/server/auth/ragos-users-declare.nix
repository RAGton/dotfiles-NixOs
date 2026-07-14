{ nodeAdminUser, nodeAdminUid, ... }:

# Declaração de usuários para o módulo node-users-btrfs.nix.
# Habilite este módulo em server.nix juntamente com node-users-btrfs.nix.
# O usuário e UID são lidos do flake.nix (nodeParams).
{
  node.users = {
    enable = true;

    users = {
      ${nodeAdminUser} = {
        uid = nodeAdminUid;
        quotaGB = 20;
      };
    };
  };
}
