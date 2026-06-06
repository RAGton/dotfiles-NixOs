---
source: docs/brain/vault.md
status: derived
canonical: false
last_sync: 2026-05-01
---

# Vault (Obsidian)

> [!IMPORTANT]
> Esta nota é derivada de `docs/`. Em caso de divergência, `docs/` vence.

O cérebro técnico e central do projeto opera num diretório formatado como Vault do Obsidian.

- **Status:** **PRODUCTION** (Base de conhecimento ativa)
- **Local:** `/home/rocha/.local/share/kryonix/kryonix-vault`

O Vault pode ser modificado com a variável ambiental `LIGHTRAG_VAULT_DIR`.

## Regras de Acesso e Operação (Obsidian CLI Brain Enforcement)

O sistema conta com regras estritas para agentes não modificarem de forma caótica as anotações centrais do usuário:

1. **Acesso com CLI**: Todo agente interagindo com o Vault deve utilizar a `kryonix vault ...` ou `kryonix brain ...` como porta de acesso e operação principal.
2. **Saúde Inicial**: Executar `kryonix brain health` e `kryonix vault scan` é o pré-requisito antes de depender do retorno do Vault.
3. **Escrita Bloqueada**: Não modificar arquivos Markdown no Vault diretamente (`sed`, `echo` ou edição file-system padrão) a não ser que o usuário autorize ativamente.
4. Caso necessite atualizar de forma profunda o Vault ou se os mecanismos de update seguros estiverem offline, crie uma proposta de update em `docs/archive/VAULT_UPDATE_PROPOSAL.md`.

## Interação Segura com o Grafo

Ao interagir com o Brain, a ordem de prioridade de fontes é:
1. Código atual do projeto
2. Documentação atual do projeto
3. Diretório `docs/agents/`
4. O Obsidian Vault acessado de modo restrito via CLI
5. A documentação oficial do produto upstream (NixOS, Hyprland, etc)
