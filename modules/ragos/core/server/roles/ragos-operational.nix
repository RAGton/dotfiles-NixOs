# ─────────────────────────────────────────────────────────────────────────────
# RAGOS — Configurações operacionais habilitadas por padrão
#
# Este módulo habilita:
#   - Auditoria de login/logout (PAM + journalctl)
#   - Grupos de usuários e storage por setor (criação dinâmica via CLI)
#   - Usuário admin de teste (rag:rag)
# ─────────────────────────────────────────────────────────────────────────────

{
  config,
  lib,
  ragosAdminUser,
  ragosAdminUid,
  ragosAdminHashedPassword,
  ...
}:

{
  # ─────────────────────────────────────────────────────────────────────────
  # Habilitar módulos de auditoria e infraestrutura de grupos
  # ─────────────────────────────────────────────────────────────────────────
  ragos.audit.enable = lib.mkDefault true;
  ragos.audit.retentionDays = lib.mkDefault 90;

  # Grupos SÃO habilitados, mas SEM predefinições
  # Criar grupos conforme necessário: ragos group add <nome> --storage-quota <tamanho>
  ragos.userGroups.enable = lib.mkDefault true;

  # Gerenciamento de usuários: provisiona teste user "rag" + homes obrigatórias
  ragos.userManagement.enable = lib.mkDefault true;

  # ─────────────────────────────────────────────────────────────────────────
  # IMPORTANTE: Para testes, criar usuário rag com senha rag
  #
  # Em produção:
  #  - Trocar ragosAdminHashedPassword em flake/runtime/params.nix
  #  - Use uma senha forte, NÃO plaintext
  #  - Considere usar chaves SSH em vez de senha
  # ─────────────────────────────────────────────────────────────────────────

  # Usuário rag está definido em server/auth/ragos-users-declare.nix
  # Este arquivo apenas confirma que deve estar presente

  environment.variables.RAGOS_ADMIN_USER = ragosAdminUser;
}
