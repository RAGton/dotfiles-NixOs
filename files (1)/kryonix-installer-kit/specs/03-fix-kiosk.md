# Spec 03 — Fix: Kiosk (Systemd + Wayland)

Implementar após backend + frontend funcionarem.

## Problemas comuns
- **kiosk.service não encontra binário**: path errado em ExecStart.
- **Wayland/display não configurado**: DISPLAY, WAYLAND_DISPLAY, XDG_RUNTIME_DIR.
- **Permissões**: usuario não em grupo certo, systemd scope.
- **Network loopback**: 127.0.0.1:8080 não alcançável dentro do kiosk.

## Implementação
1. Garantir backend + frontend funcionando (Specs 01, 02).
2. Editar kiosk.nix / launch.sh: caminhos, env vars, service unit.
3. Rodar em VM: `systemctl status kryonix-installer-kiosk` deve estar running.
4. Validar: interface visível em fullscreen.

## Validação em VM
```bash
sudo systemctl start kryonix-installer-kiosk.service
sleep 3
sudo systemctl status kryonix-installer-kiosk.service  # active (running)?
ps aux | grep kiosk   # processo vivo?
journalctl -u kryonix-installer-kiosk.service -n 20   # erros?
```
