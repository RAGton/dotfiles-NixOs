# Spec 04 — Desacoplamento do Desktop

## Estado atual (verificado)
desktop/hyprland/{system.nix,user.nix(grande),rice/}. Caelestia = QML/QuickShell,
ajustado por overrideAttrs.postPatch (remove pragma DefaultEnv). Hyprland + UWSM. DMS legado.

## Objetivos
- Quebrar user.nix em core/ (WM base), caelestia/ (shell), user-vars/.
- Opção `kryonix.desktop.shell` (enum caelestia|dms|none).
## Plano incremental (1 bloco/commit)
1. core/monitors.nix → core/rules.nix → core/keybinds.nix.
2. caelestia/ atrás da opção; preservar postPatch.
3. user-vars/; aposentar user.nix.

## Validação
build do activationPackage rocha@inspiron; kryonix test; UWSM + app gráfico + caelestia.service ok.
## Risco / Rollback
Divisão quebra binds → bloco a bloco; rollback git revert + nixos-rebuild --rollback.
