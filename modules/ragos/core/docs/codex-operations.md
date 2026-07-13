# Operacao do Codex no Repo

Status: secondary
Scope: governanca local de AGENTS, agentes customizados e skills reutilizaveis do RAGOS
Last reviewed: 2026-04-09

## Objetivo

Esta nota descreve a estrutura minima para uso disciplinado do Codex no RAGOS.

## Arquivos que governam a estrutura

- `../AGENTS.md`
  Instrucoes persistentes do projeto.
- `../.codex/config.toml`
  Defaults locais do Codex no repositorio.
- `../.codex/agents/*.toml`
  Agentes especializados por dominio.
- `../.agents/skills/*/SKILL.md`
  Workflows reutilizaveis do projeto.

## Fluxo recomendado

1. Ler `AGENTS.md`.
2. Classificar a tarefa por dominio: `server`, `client`, `installer`, `ragc`, `docs`, `inventario`, `branding` ou `validacao`.
3. Acionar agente especializado quando a tarefa exigir protecao de fronteira ou revisao profunda.
4. Acionar skill quando houver workflow repetivel ou fragil.
5. Validar a mudanca com testes proporcionais ao contrato tocado.
6. Atualizar docs no mesmo ciclo quando o contrato mudar.

## Agentes canonicos do projeto

- `arquitetura`
- `documentacao`
- `installer`
- `branding`
- `validacao`

## Skills iniciais do projeto

- `ragos-contract-audit`
- `ragos-docs-drift`
- `ragos-publish-guard`
- `ragos-inventory-audit`
- `ragos-runbook-sync`

## Regra de convivencia com estrutura antiga

A unica arvore canonica para skills do projeto e `../.agents/skills/`.

Agentes canonicos do repo vivem apenas em `../.codex/agents/` com estes nomes:

- `arquitetura`
- `documentacao`
- `installer`
- `branding`
- `validacao`

Estruturas removidas da governanca local:

- `../.codex/skills/`
- `../.codex/agents/docs_auditor.toml`
- `../.codex/agents/explorer.toml`
- `../.codex/agents/implementer.toml`
- `../.codex/agents/reviewer.toml`
- `../.codex/agents/validator.toml`

Nao reintroduza essas estruturas como fonte paralela.
