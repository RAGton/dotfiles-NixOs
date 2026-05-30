# Kryonix — Meta-Distro NixOS (memória de projeto)

Configuração NixOS declarativa baseada em Flakes, evoluindo de "dotfiles" para
distribuição upstream (exporta nixosModules, overlays, cache Cachix próprio).
Toda mudança deve manter o build reproduzível e os hosts `glacier`/`inspiron` íntegros.

## Modelo distribuído
- `glacier` = Servidor/IA (AMD/Nvidia): Ollama, LightRAG, Brain API via Tailscale. Build pesado.
- `inspiron` = Cliente/Workstation (Intel): Hyprland + Caelestia + CLI `kryonix`. Build leve.
- Compilação pesada (Rust/CUDA) acontece no Glacier ou vem do Cachix, NUNCA no Inspiron.

## Comandos (validação obrigatória)
- `nix flake check --keep-going --impure` — SEMPRE antes de commit
- `nix flake show --all-systems` — confere superfície de outputs
- `kryonix test` / `kryonix boot` — antes de `kryonix switch`
- `nix build .#nixosConfigurations.<host>.config.system.build.toplevel --no-link -L`
- `nix build .#homeConfigurations."rocha@inspiron".activationPackage --no-link -L`

## Convenções
- Composição/roteamento vive em `flake.nix` e `flake/`; hardware vive em `hosts/<h>/`.
- Opções públicas no namespace `kryonix.*` (`lib/options.nix`), com default seguro `enable = false`.
- Condicionais sempre via `lib.mkIf`; opções via `lib.mkOption` com `type` explícito.
- Pacotes consumidos via overlay (`pkgs.kryonix.<comp>`), não `import` relativo.
- Formate Nix com o formatter do flake (`nix fmt`).

## Layout
- `flake.nix` — roteador fino; `flake/` — composição (inputs, lib, data, modules, packages…)
- `hosts/<host>/` — hardware + opções de host
- `modules/`, `profiles/`, `features/` — comportamento reutilizável e papéis
- `desktop/hyprland/` — system.nix + core/ + caelestia/ + user-vars/
- `packages/` — CLI shell, kryonix-home (Rust), installer (Rust+Vite), brain (Python)
- `specs/` — especificações por fase (fonte de verdade do refactor)

## Regras críticas (VIBECODE_GOVERNANCE)
- IMPORTANT: não alucine estado. Código ativo > docs. Verifique antes de afirmar "pronto".
- IMPORTANT: nunca exponha secrets ao Nix Store. Secrets em `/etc/kryonix/brain.env` (gitignored).
- Migração incremental: um PR por item; cada PR builda os dois hosts antes do merge.
- Toda entrega traz Plano / Diff / Teste / Risco / Rollback.

@AGENTS.md
