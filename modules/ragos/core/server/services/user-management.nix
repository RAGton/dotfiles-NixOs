# ─────────────────────────────────────────────────────────────────────────────
# USER MANAGEMENT - Gerenciamento de Usuários (Dinâmico)
#
# Usuários base do RAGOS que SEMPRE devem estar presentes:
#   - rag: ADMIN de teste/laboratório (LAB-ONLY/TEMPORARY)
#     Home: /srv/data/home/rag
#     Grupo: admin
#     Quota: 20G
#     Senha: rag (hash)
# ─────────────────────────────────────────────────────────────────────────────

{
  lib,
  ...
}:

{
  options.ragos.userManagement = {
    enable = lib.mkEnableOption "RAGOS user management and CLI";
  };

  config = lib.mkIf true {
    # User management features will be added as needed
    # Currently handled by storage.nix and roles/base.nix
  };
}
