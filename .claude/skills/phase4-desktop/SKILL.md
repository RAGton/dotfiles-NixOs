---
name: phase4-desktop
description: Executa a Fase 4 do refactor Kryonix — quebrar o gigante desktop/hyprland/user.nix em camadas (WM base, Caelestia shell, variáveis de usuário). Use quando o usuário pedir para desacoplar o desktop, separar Hyprland/Caelestia, ou trabalhar na Fase 4.
allowed-tools: Read, Write, Edit, Bash(nix build:*), Bash(nix flake check:*), Grep, Glob
---

# Fase 4 — Desacoplamento do Desktop (Hyprland / Caelestia)

Leia primeiro `specs/04-desktop.md`. Mover UM bloco por commit, buildando entre cada.

## Alvo
- `desktop/hyprland/system.nix` — NixOS: programs.hyprland, portals, UWSM (mantém).
- `desktop/hyprland/core/` — HM: monitors.nix → rules.nix → keybinds.nix (sem opinião de rice).
- `desktop/hyprland/caelestia/` — HM: shell/rice atrás de `kryonix.desktop.shell == "caelestia"`.
- `desktop/hyprland/user-vars/` — env, wallpaper, tema por usuário.
- `user.nix` antigo vira agregador fino (imports) durante a transição, aposentado por último.

## Regras de ouro
- system vs user: `programs.hyprland.enable`/portals/UWSM no system; binds/rules/settings no HM.
- NUNCA `home.file.".../hyprland.conf".text` manual — usar `wayland.windowManager.hyprland.settings`.
- PRESERVAR o fix do Caelestia em `modules/nixos/desktop/caelestia/default.nix`
  (overrideAttrs.postPatch que remove `pragma DefaultEnv` do shell.qml). Não editar /nix/store.
- Nova opção `kryonix.desktop.shell` (enum caelestia|dms|none, default caelestia) em `lib/options.nix`.

## Validação / Rollback
- `nix build .#homeConfigurations."rocha@inspiron".activationPackage -L`; depois `kryonix test`.
- Validar UWSM + launch de app gráfico + caelestia.service sem erro de pragma.
- Rollback: `git revert` + `nixos-rebuild switch --rollback`.
