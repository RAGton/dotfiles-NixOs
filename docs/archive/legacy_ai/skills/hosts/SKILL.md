---
name: hosts
description: Mantém responsabilidades claras entre hosts kryonix (glacier, inspiron, inspiron-nina) e alinha decisões ao papel real de cada máquina. Use quando a tarefa envolver múltiplos hosts, risco de mudança global quando o problema é local, ou necessidade de documentar diferenças operacionais entre glacier e inspiron.
---

# Skill: Hosts

## Regra geral

Cada host deve manter responsabilidades claras e decisões alinhadas ao seu papel real.

## Regras

- não assumir que todos os hosts compartilham o mesmo risco operacional
- preservar especificidade de hardware no host certo
- evitar mudanças globais quando o problema é local de um host
- documentar diferenças relevantes de operação, não qualquer detalhe histórico

## Referências

- `ai/context/HOSTS.md`
- `docs/CURRENT_STATE.md`
- `docs/GLACIER.md`
