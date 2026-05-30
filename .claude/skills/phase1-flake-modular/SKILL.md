---
name: phase1-flake-modular
description: Executa a Fase 1 do refactor Kryonix — modularizar o flake.nix em roteador fino, extrair usuários/hosts para flake/data/, e exportar nixosModules.default + homeManagerModules + overlays para uso upstream (meta-distro). Use quando o usuário pedir para modularizar o flake, transformar em meta-distro, exportar módulos upstream ou trabalhar na Fase 1.
allowed-tools: Read, Write, Edit, Bash(nix flake check:*), Bash(nix flake show:*), Bash(nix build:*), Grep, Glob
argument-hint: "[etapa: 2|3|4]"
---

# Fase 1 — Modularização do flake.nix + Export Upstream

Leia primeiro `specs/01-flake.md`. Trabalhe UMA etapa por vez (um PR por etapa).

## Pré-requisitos
- Capturar baseline: `nix flake show --all-systems > /tmp/baseline.txt`.
- Auditar `lib/options.nix`: todo `kryonix.*` deve ter default seguro (`enable = false`)
  antes de exportar `nixosModules.default`.

## Etapas (aditivas; o caminho antigo coexiste até verde)
- **Etapa 2** — Criar `flake/inputs.nix` + `flake/lib.nix`; converter `flake.nix` em roteador fino
  (`outputs = import ./flake/<bloco>`). Não mover hosts ainda.
- **Etapa 3** — Extrair `flake/data/users.nix` e `flake/data/hosts.nix`; migrar UM host por vez
  para `mkNixosConfiguration` (começar por `inspiron`, depois `glacier`).
- **Etapa 4** — Criar `flake/modules.nix`; exportar `nixosModules.default`,
  `homeManagerModules.default` e `overlays`. Validar com um flake-consumidor mínimo.

## Validação por etapa (gate de verde)
1. `nix flake check --keep-going --impure`
2. `nix flake show --all-systems` — comparar com /tmp/baseline.txt (nenhum output some).
3. `nix build .#nixosConfigurations.inspiron.config.system.build.toplevel --no-link -L`
4. `nix build .#nixosConfigurations.glacier.config.system.build.toplevel --no-link -L`

## Risco / Rollback
- Risco: `specialArgs`/`hostname` quebrado → host não avalia. Mitigação: um host por vez.
- Rollback: `git revert` do PR; nada fora de `flake.nix`/`flake/` muda.
