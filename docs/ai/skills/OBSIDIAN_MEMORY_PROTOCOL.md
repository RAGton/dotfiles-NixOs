# Obsidian Memory Protocol — Kryonix

> Skill obrigatória para todo agente Kryonix (Aura, Claude Code, Codex,
> Cursor, ou qualquer LLM operando o repositório).

## Objetivo

O Obsidian Vault em `/home/rocha/Documents/Obsidian Vault` é a **memória
operacional e grafo de conhecimento** do projeto. Toda sessão de agente
deve ler o contexto no início e gravar resumo no final.

## Vault padrão

```
/home/rocha/Documents/Obsidian Vault
```

Estrutura nova (criada em 2026-06-14):

```
01_Kryonix/        MOC, CURRENT_STATE, ACTIVE_WORK, DECISIONS, ROADMAP, Glossary
02_Architecture/   NixOS Flakes, DEV PROD Flow, Hosts, Installer, Branding KryonixOS, Security Model
03_Operations/     Commands, Runbooks, Validation Matrix, Safe Git Workflow
04_AI_Brain/       Aura, Hermes, RAG CAG GraphRAG, Neo4j, Ollama, MCP
05_Installer/      UI Flow, Backend Routes, Target Flake v2, Network Flow, Testing
06_Hosts/          Inspiron, Glacier, Inspiron Nina, ISO
07_Branding/       KryonixOS Identity, Terminal Identity, Boot Identity
08_Sessions/YYYY-MM-DD/    sessões diárias
09_Entities/       Hosts/, Services/, Repositories/, Commands/, Issues/, Pull Requests/
_templates/        session.md, decision.md, runbook.md, entity.md, project-note.md
```

A estrutura PARA antiga (`01-Canonical`, `02-Areas` etc.) **continua
coexistindo** — não mover/apagar.

## Início de sessão

Antes de qualquer patch, ler:

1. `01_Kryonix/CURRENT_STATE.md`
2. `01_Kryonix/ACTIVE_WORK.md`
3. `01_Kryonix/DECISIONS.md`
4. `03_Operations/Safe Git Workflow.md`
5. MOC da área da tarefa (`02_..` a `07_..`)

Rodar também (preflight obrigatório):

```bash
cd /home/rocha/kryonix/kryonix || exit 1
test "$(pwd -P)" = "/home/rocha/kryonix/kryonix" || exit 1
git status --short
git log --oneline --decorate -8
```

## Durante a sessão

- Não confiar só na memória do chat.
- Registrar decisões relevantes (criar nota em `01_Kryonix/DECISIONS.md`
  ou nota dedicada com `_templates/decision.md`).
- Usar links Obsidian `[[Nome]]` para entidades.
- Usar tags descritivas: `#kryonix #installer #branding #host/glacier`,
  etc.
- **Não salvar secrets no vault**.
- **Não copiar código inteiro** — resumir, linkar, referenciar.

## Nunca copiar para o vault

```
.env, *.env, brain.env, neo4j.env
secrets, tokens, API keys
SSH/GPG private keys
cookies, browser profiles
database dumps, VM images, ISO
node_modules, .git, .direnv, result, /nix/store
```

## Final de sessão

Criar nota em:

```
08_Sessions/YYYY-MM-DD/YYYY-MM-DD-HHMM-<slug>.md
```

Usar template `_templates/session.md`. Frontmatter mínimo:

```yaml
---
type: session
project: Kryonix
date: YYYY-MM-DD
agent: aura
status: closed
tags: [kryonix, session]
---
```

Conteúdo obrigatório (seções):

- Objetivo
- Estado inicial
- Alterações realizadas
- Commits / PRs / Issues
- Validações
- Decisões novas
- Riscos
- Pendências
- Próximo passo recomendado

Atualizar também:

- `01_Kryonix/CURRENT_STATE.md` (snapshot vivo)
- `01_Kryonix/ACTIVE_WORK.md` (o que está em curso)
- `01_Kryonix/DECISIONS.md` (apenas se houve decisão nova)
- MOC da área impactada (links para a sessão)

## Formato padrão de nota

```yaml
---
type: project-note | architecture-note | ops-note | ai-note | agent-spec
       | branding-note | installer-note | host-spec | moc | session
       | entity | decision | glossary | runbook
project: Kryonix
status: active | shipped | in-progress | retired | open | closed
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags:
  - kryonix
  - ...
links:
  - "[[MOC - Kryonix]]"
  - ...
---
```

Wikilinks são preferidos a paths absolutos. Tags são hierárquicas:
`#kryonix/installer`, `#host/glacier`, `#agent/aura`.

## Critério de conclusão de tarefa

Uma tarefa só está completa quando:

- Repo validado conforme `03_Operations/Validation Matrix.md`.
- Relatório entregue no formato VIBECODE/Aura.
- **Sessão gravada no vault** em `08_Sessions/`.
- `CURRENT_STATE.md` atualizado.
- Pendências registradas em `ACTIVE_WORK.md`.

## Política de segurança do vault

- Vault é **fora do repo Git** (`/home/rocha/Documents/`), portanto não
  expõe secrets via push acidental.
- Skill `OBSIDIAN_MEMORY_PROTOCOL` no repo é a única coisa que cruza para
  o GitHub.
- Não criar atalhos/symlinks do vault para dentro do repo.

## Referências

- [[01_Kryonix/MOC - Kryonix]] — hub raiz do vault.
- [[04_AI_Brain/Aura]] — padrão operacional do agente.
- `skills/git-dev-prod/SKILL.md` — skill canônica DEV/PROD.
- `.claude/skills/git-dev-prod/SKILL.md` — variante Claude Code.
