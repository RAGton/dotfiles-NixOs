---
name: release-engineering
description: Fecha entregas kryonix com relatório curto, auditável e alinhado ao estado validado — release notes, resumo de mudança, fechamento operacional e resposta final para patches grandes. Use quando o usuário precisar documentar o que mudou, separar validações executadas de pendentes, escrever release note ou fechar uma entrega de forma verificável.
---

# Skill: Release Engineering

## Objetivo

Fechar uma entrega com relatório curto, auditável e alinhado ao estado validado.

## Quando usar

- release note
- resumo de mudança
- fechamento operacional
- resposta final para patch grande

## Entradas

- escopo da entrega
- hosts/superfícies afetadas
- validação disponível

## Passos

1. listar o que realmente mudou
2. separar validação executada de validação pendente
3. separar erro antigo de erro novo
4. escrever resumo curto e factual

## Comandos de validação

```bash
git diff --stat
nix flake show path:$PWD
nix flake check path:$PWD --keep-going
```

## Critérios de saída

- texto curto
- resultados verificáveis
- riscos restantes explícitos

## Riscos

- vender plano como entrega
- esconder limitação de ambiente ou runtime
