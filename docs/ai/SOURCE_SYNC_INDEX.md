# Hierarquia e Precedência de Fontes de Conhecimento

O projeto lida com múltiplas camadas de conhecimento e memória (repositório git, base RAG, vault local, memória da IA). Para evitar conflitos ou regressões, esta é a ordem estrita de qual fonte "vence" se houver divergência:

## 1. Código Fonte do Motor (O Rei)
Os arquivos reais `.nix`, `.sh` e `.py` dentro de `/etc/kryonix/`. Eles representam o que o sistema operacional de fato constrói.

## 2. Docs Canônicos (O Intérprete)
Arquivos em `/etc/kryonix/docs/` e `docs/ai/` que refletem explicitamente o que foi auditado no Código Fonte. Exemplo: `docs/CURRENT_STATE.md`.

## 3. Chats Antigos e Context Files
Os arquivos em `docs/archive/` refletem logs passados.

## Regra Operacional para Agentes
Se você notar uma divergência entre as discussões passadas e a implementação do código, **apresente o código** atual.
