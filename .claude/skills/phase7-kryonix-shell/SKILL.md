---
name: phase7-kryonix-shell
description: Executa a Fase 7 do refactor Kryonix — Kryonix Shell WM-first (Hyprland + Qt/QML + Rust + Home Manager). Use quando o usuário pedir para construir o shell próprio do Kryonix sobre Hyprland, kryonix-shell-daemon, kryonix-shell-ui, sddm-kryonix-theme puro (sem KDE), ou trabalhar na Fase 7.
allowed-tools: Read, Write, Edit, Bash(nix build:*), Bash(nix flake check:*), Bash(nix fmt:*), Bash(cargo:*), Bash(rg:*), Bash(find:*), Grep, Glob
---

# Fase 7 — Kryonix Shell (WM-first sobre Hyprland)

Leia primeiro `specs/07-kryonix-shell.md`. Esta skill constrói o shell nativo Kryonix
**sem KDE**: compositor Hyprland, UI em Qt/QML (Quickshell), backend em Rust.
Não confundir com Fase 8 (Aurora Shell = Kryonix sobre KDE Plasma).

## Contexto obrigatório antes de agir

Antes de qualquer mudança leia:
- `packages/kryonix-bar/` — daemon Rust existente (`org.kryonix.Bar` via D-Bus); é o **ponto de partida** do daemon, não reinventar do zero.
- `desktop/hyprland/` — estrutura ativa: `system.nix`, `core/`, `caelestia/`, `user.nix`.
- `lib/options.nix` — opções existentes (`kryonix.desktop.environment`, `kryonix.desktop.shell`).
- `specs/07-kryonix-shell.md` — fonte de verdade das fases (A→G).

## Alvo desta fase

```
packages/kryonix-shell-daemon/   ← evolução de kryonix-bar (mantém alias durante PR A)
packages/kryonix-shell-ui/       ← Quickshell + QML (Bar, Launcher, ControlCenter, Settings)
packages/sddm-kryonix-theme/     ← QML SDDM; nunca sem fallback Breeze coinstalado
modules/nixos/desktop/hyprland/shell.nix   ← módulo NixOS (desativado por default)
home/<user>/hyprland/shell.nix            ← módulo HM atrás de kryonix.desktop.shell=="kryonix"
packages/kryonix-cli/lib/shell.sh         ← kryonix shell save [--switch] [--push] [--dry]
```

## Regras de ouro (não violar)

- **API daemon SOMENTE em 127.0.0.1** — nenhum socket externo.
- **Sem blur pesado** — bg `rgba(11,15,20,0.72)`, accent `#38BDF8`, surface `#111827`.
- **Quickshell** como base QML (não reinventar SystemTray/PipeWire/UPower).
- Inspiron **nunca** compila Rust local — garantir push ao Cachix antes de switch (coordenar Fase 3).
- **kryonix.desktop.shell = "kryonix"** é opt-in; default permanece `"caelestia"`.
- Coexistência Caelestia × Kryonix Shell: assertion impede ambos ativos.
- SDDM: **sempre** coinstalar `libsForQt5.breeze-qt5` + assertion + doc de rollback no PR.
- Persistência: exato padrão da Spec 06 (`mkOutOfStoreSymlink` + `kryonix shell save`).
- KDE: **não evoluir, não remover** nesta fase.

## Ordem dos PRs (1 por vez)

```
A: opções lib/options.nix + scaffold daemon (nix build passa; sem efeito visível)
B: IPC Hyprland (.socket2.sock) + persistência TOML + hot-reload inotify
C: kryonix-shell-ui (Bar QML mínima: workspaces + CPU% + RAM% + clock)
D: módulo HM ativa daemon + Quickshell via exec-once
E: kryonix shell save (CLI subcomando)
F: sddm-kryonix-theme opt-in
G: command palette + Brain (opcional)
```

## Paleta de design (não alterar sem aprovação)

```
background:  #0B0F14     surface:     #111827
surfaceAlt:  #1E293B     accent:      #38BDF8
text:        #E5E7EB     muted:       #94A3B8
danger:      #F43F5E     warning:     #F59E0B
success:     #22C55E     panel-alpha: 0.72
```

## Validação obrigatória por PR

```bash
nix fmt
nix flake check --keep-going --impure
nix build .#kryonix-shell-daemon --no-link -L
nix build .#kryonix-shell-ui --no-link -L               # a partir do PR C
nix build .#nixosConfigurations.inspiron.config.system.build.toplevel --no-link -L
nix build .#nixosConfigurations.glacier.config.system.build.toplevel --no-link -L
nix build .#homeConfigurations."rocha@inspiron".activationPackage --no-link -L
kryonix test                                              # antes de qualquer switch
```

Smoke (host de teste, NUNCA inspiron produtivo de primeira):
- daemon sem traceback em `journalctl --user -u kryonix-shell-daemon`
- bar reflete workspace ao trocar
- editar `~/.config/kryonix-shell/settings.toml` → accent muda em < 1 s
- `kryonix shell save` → commit em `~/kryonixos/`

## Rollback

- Global: `kryonix.desktop.shell = "caelestia"` + `nixos-rebuild --rollback`.
- SDDM: `services.displayManager.sddm.theme = "breeze"` + rollback.
- Daemon: `systemctl --user stop kryonix-shell-daemon` (binário fica inerte).

## Entrega por PR

Bloco VIBECODE obrigatório:
```
Plano / Diff / Teste / Risco / Rollback
```
