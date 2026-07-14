# ─────────────────────────────────────────────────────────────────────────────
# NODE — Configurações operacionais habilitadas por padrão
#
# Este módulo habilita:
#   - Auditoria de login/logout (PAM + journalctl)
#   - Grupos de usuários e storage por setor (criação dinâmica via CLI)
#   - Usuário admin de teste (rag:rag)
# ─────────────────────────────────────────────────────────────────────────────

{
  config,
  lib,
  nodeAdminUser,
  nodeAdminUid,
  nodeAdminHashedPassword,
  ...
}:

{
  # ─────────────────────────────────────────────────────────────────────────
  # Habilitar módulos de auditoria e infraestrutura de grupos
  # ─────────────────────────────────────────────────────────────────────────
  node.audit.enable = lib.mkDefault true;
  node.audit.retentionDays = lib.mkDefault 90;

  # Grupos SÃO habilitados, mas SEM predefinições
  # Criar grupos conforme necessário: node group add <nome> --storage-quota <tamanho>
  node.userGroups.enable = lib.mkDefault true;

  # Gerenciamento de usuários: provisiona teste user "rag" + homes obrigatórias
  node.userManagement.enable = lib.mkDefault true;

  # ─────────────────────────────────────────────────────────────────────────
  # IMPORTANTE: Para testes, criar usuário rag com senha rag
  #
  # Em produção:
  #  - Trocar nodeAdminHashedPassword em flake/runtime/params.nix
  #  - Use uma senha forte, NÃO plaintext
  #  - Considere usar chaves SSH em vez de senha
  # ─────────────────────────────────────────────────────────────────────────

  # Usuário rag está definido em server/auth/node-users-declare.nix
  # Este arquivo apenas confirma que deve estar presente

  environment.variables.NODE_ADMIN_USER = nodeAdminUser;
}
