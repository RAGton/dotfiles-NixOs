# Spec 01 — Modularização do flake.nix + Export Upstream

## Estado atual (verificado)
flake.nix ~330 linhas, centraliza usuários e helpers. Hosts: inspiron, inspiron-nina,
glacier, glacier-live, iso. Homes: rocha@inspiron, rocha@glacier, nina@inspiron-nina.

## Objetivos
- flake.nix vira roteador fino; composição em `flake/`.
- Usuários/hosts saem para `flake/data/`.
- Exportar `nixosModules.default`, `homeManagerModules.default`, `overlays`.
## Não-objetivos
- Mover hardware/opções de host (ficam em hosts/).

## Plano incremental (1 PR por passo)
1. Auditar `lib/options.nix` (defaults seguros). 
2. `flake/inputs.nix` + `flake/lib.nix` + roteador fino.
3. `flake/data/{users,hosts}.nix`; migrar 1 host por vez.
4. `flake/modules.nix` + exports; validar com consumidor externo mínimo.

## Validação
flake check --keep-going; flake show (sem perder outputs); build dos 2 toplevels.
## Risco / Rollback
specialArgs/hostname quebrado → 1 host por vez; rollback via git revert.
