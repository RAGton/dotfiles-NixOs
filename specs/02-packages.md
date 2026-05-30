# Spec 02 — Ecossistema de Pacotes (callPackage)

## Estado atual (verificado)
CLI `kryonix` = writeShellApplication (shell), não Rust. Rust = kryonix-home + installer (Axum).
Brain = submódulo Python (packages/kryonix-brain-lightrag). registry.sh = fonte de comandos.

## Objetivos
- `packages/default.nix` com callPackage; casas separadas para CLI/Rust/installer/doctor/brain.
- Injeção via overlay (`pkgs.kryonix.<comp>`).
## Plano incremental
1. default.nix + mover kryonix-cli para pasta com lib/*.sh.
2. Formalizar installer/* (incl. ui.nix Vite hermético).
3. Criar kryonix-doctor (TUI Python) — novo.
4. Plugar overlay; trocar imports relativos.

## Validação
nix build dos pacotes; kryonix --help/doctor/brain health sem traceback.
## Risco / Rollback
npmDepsHash/cargoLock errados → fixar hashes; rollback via overlay.
