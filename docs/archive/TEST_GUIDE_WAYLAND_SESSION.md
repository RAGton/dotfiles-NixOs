# Guia de Testes: LightDM + Hyprland (UWSM) + DMS

## 1. Validar avaliação/build (sem aplicar)
```bash
cd /home/rocha/node-nixos
nix flake check --no-build
nix eval --json .#nixosConfigurations.inspiron.config.services.xserver.displayManager.lightdm.enable
nix eval --json .#nixosConfigurations.inspiron.config.services.displayManager.defaultSession
nix eval --json .#nixosConfigurations.inspiron.config.programs.hyprland.withUWSM
```

Esperado:
- LightDM habilitado
- defaultSession = `"hyprland-uwsm"`
- UWSM habilitado

## 2. Aplicar em modo teste (recomendado)
```bash
sudo nixos-rebuild test --flake .#inspiron
home-manager switch --flake .#rocha@inspiron
```

## 3. Validar sessão real
```bash
ls /run/current-system/sw/share/wayland-sessions/
echo "$XDG_SESSION_TYPE"
echo "$XDG_CURRENT_DESKTOP"
loginctl session-status
ps -ef | rg "Hyprland|start-hyprland|uwsm"
```

Esperado:
- `hyprland.desktop` e `hyprland-uwsm.desktop` presentes
- `XDG_SESSION_TYPE=wayland`
- sessão ativa com compositor Hyprland via UWSM

## 4. Validar DMS-only
```bash
systemctl --user list-units --type=service --state=running | rg "dms|swaync|cliphist|albert|waybar|wofi"
```

Esperado:
- `dms` ativo
- `swaync|cliphist|albert|waybar|wofi` ausentes

## 5. Validar renderer
```bash
nix shell nixpkgs#mesa-demos -c glxinfo | rg "OpenGL renderer"
```

Esperado:
- Inspiron: renderer Intel/Mesa
- Glacier: renderer NVIDIA

## 6. Troubleshooting
```bash
journalctl -b -p err
journalctl --user -b | rg -i "lightdm|hyprland|uwsm|portal|dms|powerprofiles|upower"
systemd-analyze --user blame
```

## Referências
- `docs/QUICK_START.md`
- `docs/INDEX_DOCUMENTATION.md`
- `docs/legacy/greetd/` (histórico legado removido do caminho ativo)
