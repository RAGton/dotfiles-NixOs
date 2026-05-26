# Manutenção — 2026-05-25

## Resumo

Após atualização do nixpkgs unstable para o commit `64c08a7` (2026-05-23), dois erros bloquearam
`kryonix switch`. Ambos foram corrigidos com migração real (sem allowlists permanentes). Inputs
desatualizados foram atualizados seletivamente, e o flake.nix foi reorganizado para facilitar
atualizações futuras de versão.

## Alterações

| Arquivo | Tipo | Descrição |
|---------|------|-----------|
| `desktop/hyprland/system.nix` | CRÍTICO | Remove `services.displayManager.gdm.wayland` — opção removida no GNOME 50 |
| `desktop/hyprland/system.nix` | MELHORIA | Remove linha redundante `services.xserver.displayManager.lightdm.enable` |
| `modules/nixos/common/default.nix` | CRÍTICO | Migra `nodejs_20` (EOL) → `nodejs_22` (LTS atual) em systemPackages |
| `modules/shared/nixpkgs/default.nix` | LIMPEZA | Remove overlay `wireshark-hash-fix` da lista (upstream já corrigiu) |
| `modules/home-manager/programs/git/default.nix` | ALERTA | Migra `extraOptions` deprecated em `matchBlocks` SSH → `programs.ssh.settings` |
| `overlays/default.nix` | LIMPEZA | Remove definição do overlay `wireshark-hash-fix` (hash upstream = overlay) |
| `flake.nix` | ATUALIZAÇÃO | `nixpkgs-stable`: `nixos-24.11` → `nixos-25.05` |
| `flake.nix` | ATUALIZAÇÃO | `nix-flatpak`: `v0.6.0` → `v0.7.0` |
| `flake.nix` | MELHORIA | Adiciona bloco `VERSION PINS` com comentários para facilitar atualizações futuras |
| `flake.lock` | ATUALIZAÇÃO | Lock atualizado para nixpkgs-stable (25.05) e nix-flatpak (v0.7.0) |

## Inputs atualizados seletivamente

| Input | De | Para | Método |
|-------|-----|------|--------|
| `nixpkgs-stable` | `nixos-24.11` (329 dias) | `nixos-25.05` | `nix flake lock --update-input` |
| `nix-flatpak` | `v0.6.0` (466 dias) | `v0.7.0` | `nix flake lock --update-input` |

> Nota: `rust-overlay`, `flake-utils` e `systems` são dependências transitivas (puxadas por
> `caelestia-shell` e outros inputs externos) — não são controláveis diretamente neste flake.

## Validação

- [x] `nix flake show` — exit code 0, sem erros de avaliação
- [ ] `nix build .#nixosConfigurations.inspiron.config.system.build.toplevel --no-link` — pendente
- [ ] `nix build .#nixosConfigurations.glacier.config.system.build.toplevel --no-link` — pendente
- [ ] `kryonix switch` — a executar pelo operador após revisão

## Pendências para próxima manutenção

- **overlays/default.nix — `python312-docs-stub`**: verificar se o nixpkgs atual já corrige o build
  de docs do CPython 3.12; remover se sim.
- **overlays/default.nix — `drkonqi-ignore-missing-buildid`**: verificar se upstream KDE incorporou
  a tolerância a `NoBuildIdException`.
- **overlays/default.nix — `openldap-no-checks`**: verificar se os testes do openldap i686
  passam no nixpkgs atual.
- **overlays/default.nix — `openrgb-git`**: revisar se o nixpkgs estável já tem a versão
  necessária do OpenRGB sem necessidade de pin manual.
- **inputs — `rust-overlay`** (114 dias), **`flake-utils`** (558 dias), **`systems`** (1142 dias):
  são transitivos; atualizar via inputs que os puxam (`caelestia-shell` etc.) ou aguardar
  atualização desses inputs upstream.
- **hosts/glacier/disks.nix — TODO**: substituir ID de disco placeholder pelo ID real do hardware.
