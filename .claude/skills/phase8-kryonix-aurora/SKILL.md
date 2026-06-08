---
name: phase8-kryonix-aurora
description: Executa a Fase 8 do refactor Kryonix — Kryonix Aurora Shell (camada de experiência sobre KDE Plasma 6: theme engine, bar, control center, SDDM, perfis declarativos e HM sync bridge). Use quando o usuário pedir para customizar o KDE como produto próprio, kryonix-control-center, Aurora Shell, transparência KDE, perfis KDE declarativos, ou trabalhar na Fase 8.
allowed-tools: Read, Write, Edit, Bash(nix build:*), Bash(nix flake check:*), Bash(nix fmt:*), Bash(cargo:*), Bash(rg:*), Bash(find:*), Grep, Glob
---

# Fase 8 — Kryonix Aurora Shell (KDE Plasma 6 Layer)

Leia primeiro `specs/08-kryonix-aurora-shell.md`. Esta skill constrói a camada de
experiência Kryonix **sobre o KDE Plasma 6** — não substitui KDE, **doma** o KDE.
Não confundir com Fase 7 (shell WM-first sem KDE).

## Contexto obrigatório antes de agir

Antes de qualquer mudança leia:
- `modules/nixos/desktop/kde/default.nix` — fundação KDE ativa.
- `desktop/kde/` — `theme.nix`, `kvantum.nix`, `scheme.nix`, `tiling.nix`, `keybinds.nix`.
- `packages/kryonix-bar/` — daemon Rust existente; ponto de partida do PR D (unificação).
- `packages/bonafides-theme.nix` — tema base atual.
- `lib/options.nix` — opções existentes (`kryonix.desktop.kde.*`).
- `specs/08-kryonix-aurora-shell.md` — fonte de verdade das fases (A→H).

## Alvo desta fase

```
lib/options.nix                              ← novo bloco kryonix.aurora.*
modules/nixos/desktop/kde/aurora.nix         ← módulo NixOS aurora (off por default)
desktop/kde/aurora-theme.nix                 ← tokens + transparência por classe
desktop/kde/transparency.nix                 ← window rules via plasma-manager
packages/kryonix-shell-daemon/               ← unificação de kryonix-bar + aurora daemon
packages/sddm-kryonix-theme/                 ← QML theme; sempre com fallback Breeze
packages/kryonix-control-center/             ← app Kirigami (Aparência/Bar/Atalhos/Perfis)
packages/kryonix-cli/lib/aurora.sh           ← kryonix aurora save|diff|apply|rollback
profiles/aurora/{productive,developer,...}.nix
home/<user>/generated/kryonix-shell.generated.nix
```

## Regras de ouro (não violar)

- **KDE permanece funcionando** com `kryonix.aurora.enable = false` (default seguro).
- `plasma-manager overrideConfig = false` por padrão — nunca apagar configs manuais.
- **Transparência por app, nunca global** — apenas classes listadas explicitamente.
- SDDM: **sempre** coinstalar `kdePackages.breeze` ou `libsForQt5.breeze-qt5` +
  assertion + rollback documentado; testar com `sddm-greeter --theme kryonix` antes.
- API daemon somente `127.0.0.1`; nenhum secret em `settings.toml` ou gerado.
- Persistência: exato padrão da Spec 06 (`mkOutOfStoreSymlink` + CLI sync bridge).
- `kryonix.desktop.kde.theme.colorScheme` e BonaFides **continuam funcionando** —
  Aurora é extensão, não substituição.
- Hyprland/Caelestia/Brain intocados.
- Daemon Rust: sem mudar interface D-Bus `org.kryonix.Bar` já existente sem rota de compat.

## Paleta de design Aurora

```
background:  #050A10     surface:      #0B1220
surfaceAlt:  #111827     panel-alpha:  0.78
accent:      #38BDF8     accentStrong: #0EA5E9
text:        #E5E7EB     muted:        #94A3B8
border:      #1E3A5F     danger:       #F43F5E
warning:     #F59E0B     success:      #22C55E
```

## Transparência controlada (regra explícita)

```
terminal:     0.84   fileManager:  0.92   launcher:  0.86
panel:        0.78   settings:     0.90   browser:   1.0 (opaco)
IDE/editor:   1.0   (opaco)        blur:  false (sempre)
```

## Ordem dos PRs (1 por vez)

```
A: opções kryonix.aurora.* em lib/options.nix + aurora.nix vazio
B: aurora-theme.nix (tokens) + transparency.nix (window rules por classe)
C: Kryonix Bar como Plasmoid QML (MVP: CPU/core, RAM, clock, workspaces)
D: kryonix-shell-daemon unificado (feature flags: kde-dbus + hyprland-ipc opcional)
E: kryonix aurora save|diff|apply|rollback (CLI)
F: sddm-kryonix-theme (com fallback + assertion + doc rollback + VM-first)
G: kryonix-control-center MVP (Kirigami: Aparência, Bar, Atalhos, Perfis)
H: profiles/aurora/* (productive, developer, minimal, gaming, client)
```

## Validação obrigatória por PR

```bash
nix fmt
nix flake check --keep-going --impure
nix build .#nixosConfigurations.inspiron.config.system.build.toplevel --no-link -L
nix build .#nixosConfigurations.glacier.config.system.build.toplevel --no-link -L
nix build .#homeConfigurations."rocha@inspiron".activationPackage --no-link -L
# a partir do PR D:
nix build .#kryonix-shell-daemon --no-link -L
cargo test --manifest-path packages/kryonix-shell-daemon/Cargo.toml
kryonix test
```

Smoke obrigatório:
- KDE abre sem erro com `kryonix.aurora.enable = false` (não quebrar existente).
- Com `enable = true` + `profile = "productive"`: tema aplica, bar aparece, daemon roda.
- SDDM: `sddm-greeter --theme kryonix` roda sem travar antes de ativar em produção.
- `kryonix aurora save` → commit aparece em `git log ~/kryonixos`.
- `journalctl --user -u kryonix-shell-daemon` sem traceback.

## Rollback

- Global: `kryonix.aurora.enable = false` + `nixos-rebuild --rollback`.
- SDDM: `kryonix.aurora.sddm.theme = "breeze"` + `nixos-rebuild --rollback`.
- Tema: reverter `kryonix.desktop.kde.theme.colorScheme = "bonafides"`.
- Daemon: `systemctl --user stop kryonix-shell-daemon`.

## Entrega por PR

Bloco VIBECODE obrigatório:
```
Plano / Diff / Teste / Risco / Rollback
```
