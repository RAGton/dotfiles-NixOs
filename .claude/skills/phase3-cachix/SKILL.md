---
name: phase3-cachix
description: Executa a Fase 3 do refactor Kryonix — pipeline GitHub Actions que builda derivações pesadas (Rust, CUDA/PyTorch do LightRAG) e dá push para kryonix.cachix.org. Use quando o usuário pedir CI/CD, cache binário, Cachix, build.yml, ou trabalhar na Fase 3.
allowed-tools: Read, Write, Edit, Bash(nix build:*), Bash(nix flake check:*), Grep, Glob
---

# Fase 3 — CI/CD + Cachix

Leia primeiro `specs/03-cachix.md`. Objetivo: hosts BAIXAM binários em vez de compilar.

## Pré-requisitos (uma vez, fora do código)
1. Criar cache `kryonix` no Cachix; gerar auth token de ESCRITA → GitHub Secret `CACHIX_AUTH_TOKEN`.
2. Publicar a CHAVE PÚBLICA (não-secreta) no `flake.nix` (`nixConfig.extra-substituters` +
   `extra-trusted-public-keys`) e em `nix.settings` dos hosts.

## Arquivo a criar: `.github/workflows/build.yml`
- Trigger: `push` em `main` + `workflow_dispatch` (NUNCA em PR de fork — token vazaria).
- `actions/checkout` com `submodules: recursive` (Brain é submódulo).
- `DeterminateSystems/nix-installer-action` (padrão do projeto) + `accept-flake-config = true`.
- `cachix/cachix-action@v15` com `name: kryonix`, `authToken: ${{ secrets.CACHIX_AUTH_TOKEN }}`,
  `pushFilter` para não reempurrar nixpkgs/sources.
- Matriz com derivações PRÓPRIAS pesadas: `kryonix-home`, `kryonix-installer`,
  toplevels de `glacier` e `inspiron`.
- Build via `cachix watch-exec kryonix -- nix build .#<attr> --impure -L`.

## Segurança (não-negociável)
- Token só via `secrets`. Antes de habilitar push, confirmar que o toplevel do `glacier`
  NÃO carrega `brain.env` no closure. CUDA é unfree: validar licença de redistribuição;
  na dúvida, cache PRIVADO com authtoken de leitura em `/etc/cachix` (fora do store).

## Validação / Rollback
- Em host limpo: `nix build .#kryonix-home` deve baixar de kryonix.cachix.org.
- Rollback: remover `extra-substituters`; volta a compilar local (perda de performance, não de correção).
