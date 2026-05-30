---
name: phase2-packages
description: Executa a Fase 2 do refactor Kryonix — quebrar o monólito de packages usando callPackage, dar casa ao CLI shell, ao kryonix-home (Rust), ao instalador (Rust+Vite) e ao Doctor TUI, e injetá-los via overlay. Use quando o usuário pedir para reestruturar packages/, App Store Kryonix, callPackage, ou trabalhar na Fase 2.
allowed-tools: Read, Write, Edit, Bash(nix build:*), Bash(nix flake check:*), Grep, Glob
---

# Fase 2 — Ecossistema de Pacotes (callPackage)

Leia primeiro `specs/02-packages.md`. Correção factual: o CLI `kryonix` é `writeShellApplication`
(shell), NÃO Rust. O Rust real é `kryonix-home` + a suíte do instalador.

## Alvo
- `packages/default.nix` agregador com `callPackage` (injeta deps automaticamente).
- `packages/kryonix-cli/` (shell + `registry.sh` + `lib/*.sh` fatiado por subcomando).
- `packages/kryonix-home/` (rustPlatform.buildRustPackage + cargoLock).
- `packages/installer/` (hardware-probe, disk-planner, backend Axum, `ui.nix` Vite hermético).
- `packages/kryonix-doctor/` (TUI Python — componente NOVO; até existir, shim em `kryonix doctor`).
- Overlay em `overlays/default.nix`: `kryonix = import ../packages { pkgs = final; }`.

## Regras
- Vite/npm sem rede no build: `buildNpmPackage` com `npmDepsHash` fixo.
- Rust com deps git: declarar `cargoLock.outputHashes` (ver incidente libwebrtc). Nunca `--impure` p/ esconder.
- CLI lê secrets de `/etc/kryonix/brain.env` em runtime — zero literais de credencial.

## Validação
`nix build .#kryonix .#kryonix-home .#kryonix-installer -L` ; `kryonix --help`/`doctor`/`brain health` sem traceback.
## Rollback: pacotes coexistem; reverter overlay restaura imports antigos.
