# Bateria de Testes — Kryonix Installer

> Execução em ordem. Cada seção tem critério de pass/fail objetivo.
> Nunca pular para VM antes de passar nos testes de backend.

---

## NÍVEL 1 — Backend (sem ISO, sem VM)

### 1.1 Cargo tests

```bash
cd /etc/kryonix/packages/kryonix-installer
cargo fmt --check && cargo clippy -- -D warnings && cargo test --all -- --nocapture
```

**Critério:** 13+ testes passando. Zero warnings clippy.

### 1.2 Integração via curl (backend rodando local)

```bash
# Iniciar backend
cargo run -- --port 9999 &
BACKEND_PID=$!
sleep 3

# T01: health
curl -sf http://localhost:9999/health | jq '.status' | grep -q '"ok"' && echo "T01 PASS" || echo "T01 FAIL"

# T02: probe retorna JSON com cpu e disks
curl -sf http://localhost:9999/probe | jq 'has("cpu") and has("disks")' | grep -q 'true' && echo "T02 PASS" || echo "T02 FAIL"

# T03: probe não executa nada além do binário (sem lsblk inline)
# Verificar que /probe não tem implementação de hardware em main.rs
grep -q 'lsblk\|/proc/cpuinfo' src/main.rs && echo "T03 FAIL — reimplementou probe" || echo "T03 PASS"

# T04: plan aceita request válido
curl -sf -X POST http://localhost:9999/plan \
  -H 'Content-Type: application/json' \
  -d '{"hostname":"test","timezone":"America/Cuiaba","disk":{"target":"/dev/sda","layout":"btrfs-simple"},"user":{"name":"rocha","admin":true}}' \
  | jq 'has("disk")' | grep -q 'true' && echo "T04 PASS" || echo "T04 FAIL"

# T05: dry-run rejeita disco inexistente
curl -sf -X POST http://localhost:9999/dry-run \
  -H 'Content-Type: application/json' \
  -d '{"hostname":"test","timezone":"America/Cuiaba","disk":{"target":"/dev/nonexistent999","layout":"btrfs-simple","mode":"dry-run"},"user":{"name":"rocha","admin":true}}' \
  | jq '.ok' | grep -q 'false' && echo "T05 PASS" || echo "T05 FAIL"

# T06: dry-run rejeita hostname vazio
curl -sf -X POST http://localhost:9999/dry-run \
  -H 'Content-Type: application/json' \
  -d '{"hostname":"","timezone":"America/Cuiaba","disk":{"target":"/dev/sda","layout":"btrfs-simple","mode":"dry-run"},"user":{"name":"rocha","admin":true}}' \
  | jq '.ok' | grep -q 'false' && echo "T06 PASS" || echo "T06 FAIL"

# T07: install com dry-run nunca chama executor
curl -sf -X POST http://localhost:9999/install \
  -H 'Content-Type: application/json' \
  -d '{"hostname":"test","timezone":"America/Cuiaba","disk":{"target":"/dev/sda","layout":"btrfs-simple","mode":"dry-run"},"user":{"name":"rocha","admin":true}}' \
  | jq 'has("ok")' | grep -q 'true' && echo "T07 PASS" || echo "T07 FAIL"

# T08: install real retorna 403 se safety falha (disco inexistente)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:9999/install \
  -H 'Content-Type: application/json' \
  -d '{"hostname":"test","timezone":"America/Cuiaba","disk":{"target":"/dev/nonexistent999","layout":"btrfs-simple","mode":"real"},"user":{"name":"rocha","admin":true}}')
[ "$STATUS" = "403" ] && echo "T08 PASS" || echo "T08 FAIL (got $STATUS)"

# T09: install nunca toca /dev/nvme0n1 ou disco do sistema
# (verifica que check_disk_not_system está funcionando — só em máquina com nvme)
CURRENT_DISK=$(findmnt --target / --output SOURCE --noheadings | sed 's/[0-9]*$//' | head -1)
if [ -n "$CURRENT_DISK" ]; then
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:9999/install \
    -H 'Content-Type: application/json' \
    -d "{\"hostname\":\"test\",\"timezone\":\"America/Cuiaba\",\"disk\":{\"target\":\"$CURRENT_DISK\",\"layout\":\"btrfs-simple\",\"mode\":\"real\"},\"user\":{\"name\":\"rocha\",\"admin\":true}}")
  [ "$STATUS" = "403" ] && echo "T09 PASS — disco do sistema rejeitado" || echo "T09 FAIL — PERIGOSO: disco do sistema aceito!"
fi

# T10: bind está em 127.0.0.1 (não 0.0.0.0)
grep -q '0.0.0.0' src/main.rs && echo "T10 FAIL — bind em 0.0.0.0!" || echo "T10 PASS"

kill $BACKEND_PID 2>/dev/null
```

**Critério:** T01-T10 todos PASS. T09 FAIL é crítico — parar e corrigir antes de continuar.

---

## NÍVEL 2 — Hardware Probe

```bash
cd /etc/kryonix/packages/kryonix-hardware-probe

# T11: compila e roda
cargo build -q && echo "T11 PASS" || echo "T11 FAIL"

# T12: JSON válido
cargo run -q 2>/dev/null | jq . >/dev/null && echo "T12 PASS" || echo "T12 FAIL"

# T13: campos obrigatórios presentes
OUTPUT=$(cargo run -q 2>/dev/null)
for field in cpu memory_gb disks gpu boot_mode; do
  echo "$OUTPUT" | jq "has(\"$field\")" | grep -q 'true' && echo "T13-$field PASS" || echo "T13-$field FAIL"
done

# T14: boot_mode é uefi ou bios
echo "$OUTPUT" | jq '.boot_mode' | grep -qE '"uefi"|"bios"' && echo "T14 PASS" || echo "T14 FAIL"

# T15: disks é array não-vazio
echo "$OUTPUT" | jq '.disks | length > 0' | grep -q 'true' && echo "T15 PASS" || echo "T15 FAIL"

# T16: cpu.threads > 0
echo "$OUTPUT" | jq '.cpu.threads > 0' | grep -q 'true' && echo "T16 PASS" || echo "T16 FAIL"

# T17: memory_gb > 0
echo "$OUTPUT" | jq '.memory_gb > 0' | grep -q 'true' && echo "T17 PASS" || echo "T17 FAIL"
```

**Critério:** T11-T17 todos PASS.

---

## NÍVEL 3 — Frontend (sem ISO)

```bash
# Iniciar backend + servir frontend
cargo run --manifest-path /etc/kryonix/packages/kryonix-installer/Cargo.toml -- --port 9999 &
BACKEND_PID=$!
sleep 3

# T18: frontend carrega (200 OK)
curl -sf http://localhost:9999/ > /tmp/frontend.html && echo "T18 PASS" || echo "T18 FAIL"

# T19: zero dependências externas (sem CDN, sem fetch externo)
grep -qiE 'cdn\.|googleapis\.|cloudflare\.|jsdelivr\.|unpkg\.' /tmp/frontend.html \
  && echo "T19 FAIL — dependência externa encontrada!" || echo "T19 PASS"

# T20: lockdown de teclado está como primeiro código
head -50 /etc/kryonix/packages/kryonix-installer/ui/static/app.js \
  | grep -q 'keydown\|preventDefault' && echo "T20 PASS" || echo "T20 FAIL"

# T21: EventSource presente (SSE progress)
grep -q 'EventSource' /etc/kryonix/packages/kryonix-installer/ui/static/app.js \
  && echo "T21 PASS" || echo "T21 FAIL — SSE não conectado ao /install/progress"

# T22: confirmação antes de /install (checkbox ou confirm)
grep -qiE 'checkbox|confirm|apagados|destruídos' \
  /etc/kryonix/packages/kryonix-installer/ui/static/app.js \
  && echo "T22 PASS" || echo "T22 FAIL — sem confirmação de destruição de dados"

kill $BACKEND_PID 2>/dev/null
```

**Critério:** T18-T22 todos PASS. T21 e T22 são críticos.

---

## NÍVEL 4 — ISO Build

```bash
# T23: dry-run da ISO passa (não faz build real)
nix build /etc/kryonix#nixosConfigurations.iso.config.system.build.isoImage \
  --dry-run 2>&1 | grep -q 'error' && echo "T23 FAIL" || echo "T23 PASS"

# T24: build real da ISO (demora ~10 min)
nix build /etc/kryonix#nixosConfigurations.iso.config.system.build.isoImage \
  -o /tmp/result-iso -L 2>&1 | tail -5
ls /tmp/result-iso/iso/*.iso > /dev/null 2>&1 && echo "T24 PASS" || echo "T24 FAIL"

# T25: ISO tem kryonix-hardware-probe incluído
# Checar no closure da ISO
nix path-info --recursive /tmp/result-iso \
  | grep -q 'kryonix-hardware-probe' && echo "T25 PASS" || echo "T25 FAIL — probe não está na ISO"

# T26: ISO tem cage e chromium incluídos
nix path-info --recursive /tmp/result-iso \
  | grep -q 'cage' && echo "T26-cage PASS" || echo "T26-cage FAIL"
nix path-info --recursive /tmp/result-iso \
  | grep -q 'chromium' && echo "T26-chromium PASS" || echo "T26-chromium FAIL"
```

**Critério:** T23 obrigatório antes do build. T24-T26 após build completo.

---

## NÍVEL 5 — VM Boot (requer qemu)

```bash
# Preparar disco virtual
qemu-img create -f qcow2 /tmp/test-disk.qcow2 15G

# Iniciar VM (deixar rodando e fazer testes manuais)
qemu-system-x86_64 \
  -m 4096 \
  -cpu host \
  -enable-kvm \
  -vga virtio \
  -display gtk \
  -drive file=/tmp/test-disk.qcow2,if=virtio,format=qcow2 \
  -cdrom /tmp/result-iso/iso/*.iso \
  -boot d \
  -serial mon:stdio 2>/dev/null &
```

### Checklist manual na VM

```
BOOT
[ ] T27: Plymouth aparece durante boot (não verbose)
[ ] T28: GRUB com fundo (não preto)
[ ] T29: Auto-login no TTY1 sem prompt de senha

KIOSK
[ ] T30: Cage sobe automaticamente (sem "cannot take TTY")
[ ] T31: Chromium abre em kiosk mode (sem barra de endereço)
[ ] T32: URL abre http://localhost:8080
[ ] T33: F5 não recarrega (lockdown ativo)
[ ] T34: Ctrl+R não recarrega
[ ] T35: Ctrl+Alt+F2 não muda de TTY
[ ] T36: Clique direito não abre menu de contexto
[ ] T37: Não é possível digitar URL diferente

INSTALADOR — UI
[ ] T38: Step 1 carrega hardware real da VM (CPU, disco virtual)
[ ] T39: Step 4 lista /dev/vda (disco virtual da VM)
[ ] T40: Step indicator mostra progresso correto
[ ] T41: Validação em tempo real no campo hostname
[ ] T42: Botão Próximo desabilitado se campos inválidos

INSTALADOR — BACKEND
[ ] T43: POST /dry-run valida sem executar
[ ] T44: Botão Instalar só fica ativo após dry-run passar
[ ] T45: Modal de confirmação aparece antes de POST /install
[ ] T46: Checkbox "entendo que os dados serão apagados" obrigatório

INSTALADOR — EXECUÇÃO (apenas com disco virtual, nunca com /dev/sda/nvme do sistema)
[ ] T47: POST /install retorna 403 se disco alvo = /dev/sda do sistema
[ ] T48: POST /install retorna 202+job_id para /dev/vda (disco virtual)
[ ] T49: /install/progress SSE mostra atualizações
[ ] T50: Barra de progresso avança até 100%
[ ] T51: Mensagem "Instalação concluída" aparece
[ ] T52: Sistema inicializa após reboot da VM (verifica que nixos-install funcionou)
```

---

## NÍVEL 6 — Segurança

```bash
# T53: backend NÃO escuta em 0.0.0.0
ss -tlnp | grep 9999 | grep -q '0.0.0.0' && echo "T53 FAIL — exposição pública!" || echo "T53 PASS"

# T54: Chromium não tem acesso à internet (apenas localhost)
# Dentro da VM: tentar abrir URL externa falha
# Manual: Inspecionar flags de inicialização do Chromium
grep -q 'disable-background-networking' \
  /etc/kryonix/modules/nixos/installer/web-kiosk.nix && echo "T54 PASS" || echo "T54 FAIL"

# T55: VT switching bloqueado na config NixOS
grep -qE 'vt.global_cursor_default|HandlePowerKey' \
  /etc/kryonix/modules/nixos/installer/web-kiosk.nix && echo "T55 PASS" || echo "T55 FAIL"

# T56: check_disk_not_system usa findmnt (não hardcoded)
grep -q 'findmnt' \
  /etc/kryonix/packages/kryonix-installer/src/executor/safety.rs && echo "T56 PASS" || echo "T56 FAIL"

# T57: disko nunca chamado com mode=dry-run
grep -A5 'dry.run\|dry_run' \
  /etc/kryonix/packages/kryonix-installer/src/main.rs \
  | grep -q 'run_installation\|run_disko' && echo "T57 FAIL — disko chamado no dry-run!" || echo "T57 PASS"
```

**Critério:** T53-T57 todos PASS. T53 e T57 são críticos.

---

## Sumário de execução

```bash
# Rodar Níveis 1-3 automatizados de uma vez
echo "=== NÍVEL 1: Backend ==="
# [testes T01-T10]

echo "=== NÍVEL 2: Probe ==="
# [testes T11-T17]

echo "=== NÍVEL 3: Frontend ==="
# [testes T18-T22]

echo "=== NÍVEL 6: Segurança ==="
# [testes T53-T57]

# Resultado esperado antes da ISO build:
# PASS: T01-T22, T53-T57 = 27 testes automatizados
# FAIL em qualquer um = parar e corrigir antes de continuar
```

---

## Critério de release

```
Nível 1 (backend):      27 testes → todos PASS
Nível 2 (probe):        7 testes  → todos PASS
Nível 3 (frontend):     5 testes  → todos PASS
Nível 4 (ISO build):    4 testes  → T23 obrigatório
Nível 5 (VM manual):    26 checks → T47/T48/T49 críticos
Nível 6 (segurança):    5 testes  → todos PASS, sem exceção
```
