# Spec 00 — Auditoria e Padrão de Diretórios

## Resumo
Antes de qualquer refactor, gerar inventário fiel do repo, achar redundância e propor
taxonomia de diretórios mais auditável. Executado pela skill `kryonix-audit`.

## Objetivos
- Mapear todas as pastas/arquivos por classe e estado (estável/refatorar/lixo).
- Identificar docs duplicadas e pastas de contexto fragmentadas (.ai/.agents/.context/context).
- Propor árvore-alvo e plano de movimentação incremental.
## Não-objetivos
- Mover/apagar arquivos (isso vem depois, PR a PR).

## Validação
- `find`, `rg`, contagem por extensão; `.gitignore` cobre `*.env`, `*.secret`, `result*`.
## Risco / Rollback
- Risco zero (read-only). Rollback: n/a.
