# Camada de IA do Kryonix

Esta pasta organiza o material que orienta agentes e assistentes sobre o estado real do projeto.

Ela serve para:

- concentrar contexto canônico via Vault (Obsidian)
- guardar prompts reutilizáveis
- registrar skills por domínio
- oferecer templates para novos artefatos

## Estrutura

- `kryonix-vault/`: Base de conhecimento curada, estruturada e navegável (Obsidian).
- `prompts/`: prompts prontos para tarefas recorrentes.
- `skills/`: instruções operacionais por área do projeto.
- `templates/`: moldes para criar novos prompts, skills e checklists.

## Como o Agente deve usar

1. Começar por [INDEX.md](INDEX.md).
2. Consultar o Vault em `kryonix-vault/01-Canonical/` para definições de arquitetura e uso.
3. Abrir apenas o prompt e a skill relevantes para a tarefa.
4. Propor mudanças pequenas, verificáveis e alinhadas ao estado atual.

Os agentes devem evitar:

- inventar arquitetura paralela.
- reabrir decisões já descritas nos documentos canônicos.
- espalhar regras operacionais em comentários soltos pelo repo.

## Evolução do Conhecimento

O conhecimento deve fluir de:
`Discussão` -> `Código/Docs` -> `Vault (Obsidian)` -> `Skills/Prompts`.

O Vault é a representação navegável e curada da documentação canônica, servindo como a principal base de grounding para o RAG/Brain.
