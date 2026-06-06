# Runbook: Docs Audit

Procedimento de auditoria de conformidade de documentação técnica.

## Quando usar
- Integração contínua (CI).
- Revisão manual de novos documentos.

## Procedimento
Execute o script diretamente:
```sh
./scripts/doc-audit.sh
```

## Regras de Ouro
1. **Verdade Operacional**: O que está em `docs/` deve refletir o runtime real.
2. **Roadmap Separation**: Features não validadas devem estar em `ROADMAP.md`, nunca em `USAGE.md` ou `ARCHITECTURE.md`.
3. **No Placeholders**: Evitar "TODO" ou seções vazias.

## Resolução
Se o audit falhar:
- Mova promessas futuras para o Roadmap.
- Registre evidências de teste se o comando falhar mas o código estiver correto.
