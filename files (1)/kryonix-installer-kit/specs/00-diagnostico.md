# Spec 00 — Diagnóstico Inicial do Installer

## Estado Atual (Verificado)
Kiosk não lança a interface web. Web installer existe mas não está sendo servida corretamente em fullscreen.
Suspeitas: (a) backend não compila, (b) frontend não builda, (c) kiosk.service não inicia, (d) binding de porta quebrado.

## Objetivos
- Rodar cada componente isoladamente (backend, frontend, kiosk).
- Capturar erros reais (compilação, runtime, network).
- Documentar o estado de cada um.

## Não-Objetivos
- Consertar código ainda. Só diagnosticar.

## Passos (rode cada um)

### 1. Backend (Axum)
```bash
cd packages/kryonix-installer/backend
cargo build --release 2>&1 | head -30
echo "Status: $?"
```
Procure: erro de compilação, linking, dependencies.

### 2. Frontend (Vite)
```bash
cd packages/kryonix-installer/frontend
npm run build 2>&1 | tail -20
echo "Status: $?"
ls -lah dist/
```
Procure: erro de build, assets faltando, imports quebrados.

### 3. Kiosk (systemd service)
```bash
sudo systemctl status kryonix-installer-kiosk.service
sudo journalctl -u kryonix-installer-kiosk.service -n 50
```
Procure: "failed", "Connection refused", "file not found", wayland issues.

### 4. Backend Health Check (se running)
```bash
curl -s http://localhost:8080/api/health 2>&1 || echo "Backend not responding"
```

### 5. Logs Combined
```bash
journalctl -u kryonix-installer-*.service --no-pager | tail -100
```

## Saída Obrigatória
Tabela:

| Componente | Status | Erro Principal | Ação Proposta |
|---|---|---|---|
| Backend (cargo) | ✗/✓ | ... | ... |
| Frontend (npm) | ✗/✓ | ... | ... |
| Kiosk (systemd) | ✗/✓ | ... | ... |
| Port 8080 | ✗/✓ | ... | ... |

## Rollback
Nada foi tocado — diagnostics only.
