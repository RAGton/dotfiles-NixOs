---
name: installer-diagnose
description: Diagnostica o Kryonix Installer em detalhes — compila backend, builda frontend, checa kiosk.service, testa port 8080. Use quando o instalador não funciona ou você quer um check completo antes de mexer.
allowed-tools: Bash, Read, Grep, Glob
argument-hint: "[component: all|backend|frontend|kiosk]"
---

# Diagnóstico do Installer

Leia `specs/00-diagnostico.md` primeiro.

## Passos
1. **Backend**: cargo build --release em packages/kryonix-installer/backend/
2. **Frontend**: npm run build em packages/kryonix-installer/frontend/
3. **Kiosk**: systemctl status kryonix-installer-kiosk.service
4. **Port**: curl http://localhost:8080/api/health
5. **Logs**: journalctl -u kryonix-installer-*.service -n 50

Rode cada um, capture o stderr/stdout real, NÃO alucine. Depois gere uma tabela com status.
