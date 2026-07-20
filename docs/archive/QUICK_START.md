# Quick Start: LightDM + Hyprland (UWSM) + DMS

## Passo 1: Testar sem trocar geração
```bash
cd /home/rocha/node-nixos
sudo nixos-rebuild test --flake .#inspiron
home-manager switch --flake .#rocha@inspiron
```

## Passo 2: Validar sessão
```bash
echo "$XDG_SESSION_TYPE"
loginctl session-status
systemctl --user list-units --type=service --state=running | rg "dms|swaync|cliphist|albert|waybar|wofi"
```

Esperado:
- `XDG_SESSION_TYPE=wayland`
- sessão de login via display manager LightDM
- apenas `dms` ativo entre os componentes de shell/launcher/notificação/clipboard

## Passo 3: Aplicar definitivo
```bash
sudo nixos-rebuild switch --flake .#inspiron
sudo reboot
```

## Troubleshooting rápido
```bash
journalctl -b -p err
journalctl --user -b | rg -i "hyprland|uwsm|lightdm|dms|portal"
```

## Documentação
- `docs/TEST_GUIDE_WAYLAND_SESSION.md`
- `docs/INDEX_DOCUMENTATION.md`
- `docs/legacy/greetd/` (histórico legado)
