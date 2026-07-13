{
  lib,
  pkgs,
  ragosAdminUser,
  ragosAdminUid,
  ragosAdminHashedPassword,
  ragosAdminAuthorizedKeys ? [ ],
  ragosClientUsers ? { },
  ...
}:

let
  defaultUserGroups = [
    "video"
    "audio"
  ];

  reservedClientGroups = [
    "audio"
    "nogroup"
    "root"
    "users"
    "video"
    "wheel"
  ];

  adminSpec = {
    uid = ragosAdminUid;
    description = "RAGOS Admin";
    hashedPassword = ragosAdminHashedPassword;
    authorizedKeys = ragosAdminAuthorizedKeys;
    extraGroups = [ "wheel" ] ++ defaultUserGroups;
  };

  runtimeUsers = lib.mapAttrs (
    name: spec: if name == ragosAdminUser then adminSpec // spec else spec
  ) ragosClientUsers;

  managedUsers =
    lib.optionalAttrs (ragosAdminUser != "" && ragosAdminUser != null) {
      "${ragosAdminUser}" = adminSpec;
    }
    // runtimeUsers;

  managedGroupGids = lib.foldl' (
    acc: spec:
    let
      groupGids = spec.groupGids or { };
      filteredGroupGids = lib.filterAttrs (
        groupName: gid: gid != null && !(builtins.elem groupName reservedClientGroups)
      ) groupGids;
    in
    acc
    // lib.mapAttrs (_groupName: gid: {
      inherit gid;
    }) filteredGroupGids
  ) { } (lib.attrValues managedUsers);

  mkUser = name: spec: {
    isNormalUser = true;
    description =
      if spec ? description && spec.description != "" then spec.description else "RAGOS User";
    uid =
      if spec ? uid then
        spec.uid
      else if name == ragosAdminUser then
        ragosAdminUid
      else
        throw "RAGOS: usuario ${name} precisa declarar uid no catalogo clientUsers";
    home = "/home/${name}";
    # A home persistente e montada sob demanda via pam_mount. Criar home local
    # aqui mascara falhas reais de NFS e faz a sessao cair em tmpfs efemero.
    createHome = false;
    shell = pkgs.bashInteractive;
    extraGroups =
      if spec ? extraGroups then
        spec.extraGroups
      else if name == ragosAdminUser then
        adminSpec.extraGroups
      else
        defaultUserGroups;
    hashedPassword =
      if spec ? hashedPassword then
        spec.hashedPassword
      else if name == ragosAdminUser then
        ragosAdminHashedPassword
      else
        "!";
    openssh.authorizedKeys.keys =
      if spec ? authorizedKeys then
        spec.authorizedKeys
      else if name == ragosAdminUser then
        ragosAdminAuthorizedKeys
      else
        [ ];
  };
in
{
  users.mutableUsers = false;

  users.groups = managedGroupGids;
  users.users = lib.mapAttrs mkUser managedUsers;
}
