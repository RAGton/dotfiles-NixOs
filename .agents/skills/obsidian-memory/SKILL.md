---
name: obsidian-memory
description: Opera a camada de memória local do usuário no kryonix via Obsidian — gerenciamento de vault, integração com repositório e documentação de fluxos para agentes. Use quando a tarefa envolver notas locais, operação de vault Obsidian, integração entre o repositório kryonix e conhecimento externo do usuário, ou configuração de sync entre desktop, CLI e headless.
---

# Skill: Obsidian Memory

## Objetivo

Documentar e operar a camada de memória local do usuário sem confundir app desktop, CLI e Headless Sync.

## Quando usar

- notas locais
- operação de vault
- integração entre repositório e conhecimento externo do usuário
- documentação de fluxo para agentes

## Entradas

- vault alvo ou ausência de confirmação
- superfície desejada: desktop, CLI ou headless
- objetivo operacional

## Passos

1. confirmar qual superfície está em jogo
2. não assumir vault ou path sem evidência
3. usar referências oficiais do Obsidian para CLI/URI/Headless
4. separar conhecimento do usuário do conteúdo do repositório
5. registrar runbook curto se o fluxo for recorrente

## Comandos de validação

```bash
pgrep -af obsidian
ls ~/.config/obsidian/
find ~/ -name "*.md" -path "*obsidian*" -maxdepth 6
```

## Critérios de saída

- distinção clara entre desktop, CLI e headless
- nenhum path inventado
- fluxo reproduzível documentado

## Riscos

- tratar vault pessoal como se fosse arquivo do repo
- afirmar suporte headless sem instalação correspondente
