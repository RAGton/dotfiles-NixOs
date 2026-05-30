---
name: kryonix-audit
description: Audita a estrutura completa do repositório Kryonix (pastas, arquivos, redundância, docs fragmentadas, scripts mortos, artefatos de build). Use quando o usuário pedir auditoria, varredura do repo, achar arquivos redundantes, propor renomeação de diretórios ou um padrão de projeto mais auditável. NÃO use para editar config NixOS — use a skill de rebuild.
allowed-tools: Bash(rg:*), Bash(find:*), Bash(wc:*), Bash(git:*), Bash(du:*), Read, Grep, Glob
argument-hint: "[caminho opcional]"
---

# Auditoria estrutural do Kryonix

Objetivo: gerar um **inventário fiel ao estado real** (sem alucinar), apontar redundância e
propor uma taxonomia de diretórios mais auditável — SEM mover nada nesta etapa.

## Coleta (rode e analise a saída)
- Árvore principal: !`find . -maxdepth 2 -type d -not -path '*/.git/*' | sort`
- Contagem por tipo: !`for e in nix md sh rs py; do printf "%s: " "$e"; find . -name "*.$e" -not -path '*/.git/*' | wc -l; done`
- Docs (.md): !`find docs -name '*.md' 2>/dev/null | wc -l`
- Artefatos soltos: !`find . -maxdepth 2 -name 'result' -o -name 'result-*' 2>/dev/null`
- Marcadores de pendência: !`rg -n "TODO|WIP|FIXME|não implementado|placeholder" docs/ 2>/dev/null | head -30`
- Conflitos git: !`rg -n "^<<<<<<<|^>>>>>>>|^=======" . 2>/dev/null | head`

## Análise (passos)
1. **Inventário**: para cada diretório de topo, classifique (Core Nix / Hosts / Módulos /
   Home / Desktop / Packages / Scripts / Docs / Context-AI / Config). Estado: estável / refatorar / lixo.
2. **Redundância**: identifique docs duplicadas (múltiplos README/ARCHITECTURE/CURRENT_STATE),
   pastas de contexto fragmentadas (`.ai/ .agents/ .context/ context/`), scripts sem uso real.
3. **Renomeação/padrão**: proponha taxonomia alvo. Padrão conservador (mantém `hosts/ modules/
   desktop/`, só consolida fragmentos) por default; agressivo só se o usuário pedir.
4. **Segurança**: confirme que secrets (`*.env`, `*.secret`) estão no `.gitignore` e fora do store.

## Saída obrigatória
Tabela `Caminho | Classe | Estado | Ação recomendada`, seguida de:
- Lista de redundâncias concretas (com caminhos reais).
- Árvore-alvo proposta (em bloco de código).
- Plano de migração incremental (um movimento por PR) com Risco/Rollback de cada um.
NÃO mova nem apague arquivos nesta skill — apenas relate.
