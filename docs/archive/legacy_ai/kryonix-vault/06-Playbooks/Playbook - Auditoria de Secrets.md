# Playbook - Auditoria de Secrets

## Objetivo

Encontrar e corrigir vazamentos de credenciais.

## Procedimento

1. Verificar `.env`, logs, CI, commits.
2. Rodar scanner quando disponível.
3. Revogar segredo exposto.
4. Rotacionar credencial.
5. Remover histórico se necessário.
6. Adicionar prevenção.

## Links

- [[02-Areas/Seguranca/Secrets e Credenciais]]
- [[05-Skills/auditoria-secrets/SKILL]]
