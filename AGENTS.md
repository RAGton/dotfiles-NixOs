# Kryonix Core Agent Context

Este repositório contém apenas o core/motor da distro Kryonix.

## Regra principal

O core deve permanecer limpo, sem contexto pesado de IA, prompts, skills, workflows ou memória operacional de agentes.

## Contexto completo de desenvolvimento

O contexto completo para Aura, Codex, Claude, prompts, skills, workflows e automação multi-repo vive em:

https://github.com/RAGton/kryonix-dev

Workspace local recomendado:

```bash
/home/rocha/kryonix/kryonix-dev
```

## Regras para agentes

* Não desenvolver diretamente em `/etc/kryonix`.
* Usar `/home/rocha/kryonix/kryonix-dev` como workspace.
* Não criar Git submodules dentro do core.
* Dependências externas devem ser consumidas via flake inputs.

## Versionamento e release

Este repo segue a **diretriz canônica unificada** do ecossistema Kryonix:

- **SSOT canônico:** [[kryonix-vault/02-Areas/Kryonix/canonical/release-process.md]]
- **Skill procedural:** `~/.hermes/skills/kryonix-versioning.md`
- **Manifesto:** `flake.nix` (atributo `version`)
- **Tag prefix:** `v` (e.g., `v1.0.0`)

Antes de qualquer bump de versão, carregue a skill e siga o procedimento SSOT.
