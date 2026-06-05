#!/usr/bin/env bash
# Kryonix ISO/Kiosk/Installer validation through libvirt + qemu-guest-agent.
# Safe by default: real disk mutation inside the VM only runs with
# --destructive-vm-install.

set -euo pipefail

ISO_PATH="result/iso/kryonix.iso"
CI_MODE=false
RUN_INSTALL=false

while [ "$#" -gt 0 ]; do
    case "$1" in
        --ci)
            CI_MODE=true
            shift
            ;;
        --destructive-vm-install)
            RUN_INSTALL=true
            shift
            ;;
        -h|--help)
            cat <<'EOF'
Usage:
  scripts/test-iso-boot.sh [ISO_PATH] [--ci] [--destructive-vm-install]

Default validates boot, kiosk/backend health, hardware, disks and dry-run.
--destructive-vm-install additionally runs POST /install against /dev/vda
inside the disposable VM only.
EOF
            exit 0
            ;;
        *)
            ISO_PATH="$1"
            shift
            ;;
    esac
done

if [ ! -f "$ISO_PATH" ]; then
    echo "ISO nao encontrada em $ISO_PATH. Gere a ISO antes do teste."
    exit 1
fi

VM_NAME="kryonix-stress-$(date +%s)"
DISK_PATH="/tmp/$VM_NAME-target.qcow2"
SERIAL_LOG="/tmp/$VM_NAME-serial.log"
BACKEND_LOG="/tmp/$VM_NAME-backend.log"
SCREENSHOT_ERR="/tmp/$VM_NAME-error.ppm"
SCREENSHOT_OK="/tmp/$VM_NAME-success.ppm"

cleanup() {
    local exit_code=$?

    if [ "$exit_code" -ne 0 ]; then
        echo "Falha na validacao. Coletando evidencias basicas..."
        sudo virsh screenshot "$VM_NAME" "$SCREENSHOT_ERR" >/dev/null 2>&1 || true
        guest_exec "journalctl -u kryonix-installer-backend --no-pager -n 200" >"$BACKEND_LOG" 2>/dev/null || true
        echo "Screenshot de erro: $SCREENSHOT_ERR"
        echo "Console serial preservado: $SERIAL_LOG"
        echo "Log do backend preservado: $BACKEND_LOG"
        echo "Ultimas linhas do console serial:"
        sudo tail -n 120 "$SERIAL_LOG" 2>/dev/null || true
        if [ -s "$BACKEND_LOG" ]; then
            echo "Ultimas linhas do backend:"
            tail -n 80 "$BACKEND_LOG" || true
        fi
    fi

    echo "Limpando VM efemera $VM_NAME..."
    sudo virsh destroy "$VM_NAME" >/dev/null 2>&1 || true
    sudo virsh undefine "$VM_NAME" --nvram --remove-all-storage >/dev/null 2>&1 || true
    sudo rm -f "$DISK_PATH"
    if [ "$exit_code" -eq 0 ]; then
        sudo rm -f "$SERIAL_LOG" "$BACKEND_LOG" "$SCREENSHOT_ERR" "$SCREENSHOT_OK"
    fi
    exit "$exit_code"
}
trap cleanup EXIT

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Comando obrigatorio ausente: $1" >&2
        exit 2
    }
}

require_cmd jq
require_cmd base64
require_cmd qemu-img
require_cmd virt-install
require_cmd virsh

guest_agent() {
    sudo virsh qemu-agent-command "$VM_NAME" "$1"
}

guest_exec() {
    local cmd="$1"
    local request response pid status exited exit_code out_b64 err_b64

    request=$(jq -n --arg cmd "$cmd" '{
      execute: "guest-exec",
      arguments: {
        path: "/bin/sh",
        arg: ["-lc", $cmd],
        "capture-output": true
      }
    }')

    response=$(guest_agent "$request")
    pid=$(jq -r '.return.pid' <<<"$response")

    for _ in $(seq 1 120); do
        status=$(guest_agent "$(jq -n --argjson pid "$pid" '{execute:"guest-exec-status", arguments:{pid:$pid}}')")
        exited=$(jq -r '.return.exited' <<<"$status")
        if [ "$exited" = "true" ]; then
            exit_code=$(jq -r '.return.exitcode // 0' <<<"$status")
            out_b64=$(jq -r '.return."out-data" // ""' <<<"$status")
            err_b64=$(jq -r '.return."err-data" // ""' <<<"$status")
            if [ -n "$out_b64" ]; then printf '%s' "$out_b64" | base64 -d; fi
            if [ -n "$err_b64" ]; then printf '%s' "$err_b64" | base64 -d >&2; fi
            return "$exit_code"
        fi
        sleep 1
    done

    echo "guest-exec expirou: $cmd" >&2
    return 124
}

guest_curl() {
    guest_exec "curl -fsS --max-time 15 $*"
}

# Inspeciona o QCOW2 OFFLINE (VM desligada) e exige prova estrutural de uma
# instalação real: tabela GPT + ESP (vfat) + root (btrfs/ext4). Um disco
# intocado (disk size ~196K, sem disklabel) reprova aqui — fim do falso positivo.
inspect_qcow2_offline() {
    local img="$1"
    local nbd="/dev/nbd0"
    local rc=0

    echo "Inspeção offline read-only: $img"
    echo "  qemu-img disk size: $(qemu-img info "$img" | awk -F': ' '/disk size/ {print $2}')"

    sudo modprobe nbd max_part=16 2>/dev/null || true
    sudo qemu-nbd --disconnect "$nbd" >/dev/null 2>&1 || true
    if ! sudo qemu-nbd --read-only --connect="$nbd" "$img"; then
        echo "FALHA: qemu-nbd não conectou $img"
        return 1
    fi
    sleep 1

    local pttype has_vfat has_rootfs
    pttype=$(lsblk -ndo PTTYPE "$nbd" 2>/dev/null | head -n1)
    echo "  PTTYPE=$pttype"
    sudo blkid "${nbd}"* 2>/dev/null || true
    has_vfat=$(sudo blkid "${nbd}"* 2>/dev/null | grep -c 'TYPE="vfat"' || true)
    has_rootfs=$(sudo blkid "${nbd}"* 2>/dev/null | grep -Ec 'TYPE="(btrfs|ext4)"' || true)

    [ "$pttype" = "gpt" ]   || { echo "  FALHA: sem tabela GPT (disko não particionou)"; rc=1; }
    [ "${has_vfat:-0}" -ge 1 ]   || { echo "  FALHA: sem partição ESP vfat"; rc=1; }
    [ "${has_rootfs:-0}" -ge 1 ] || { echo "  FALHA: sem root btrfs/ext4"; rc=1; }

    sudo qemu-nbd --disconnect "$nbd" >/dev/null 2>&1 || true
    [ "$rc" -eq 0 ] && echo "  OK: GPT + ESP + root presentes no disco."
    return "$rc"
}

echo "Preparando disco virtual descartavel..."
    sudo rm -f "$DISK_PATH" "$SERIAL_LOG" "$BACKEND_LOG" "$SCREENSHOT_ERR" "$SCREENSHOT_OK"
qemu-img create -f qcow2 "$DISK_PATH" 32G >/dev/null

if ! sudo virsh net-info default | rg -q 'Active:.*yes'; then
    sudo virsh net-start default >/dev/null 2>&1 || true
fi

echo "Provisionando VM libvirt..."
sudo virt-install \
    --name "$VM_NAME" \
    --memory 4096 \
    --vcpus 2 \
    --disk path="$DISK_PATH",format=qcow2,bus=virtio \
    --cdrom "$ISO_PATH" \
    --os-variant nixos-unstable \
    --boot uefi \
    --network network=default,model=virtio \
    --graphics spice \
    --serial file,path="$SERIAL_LOG" \
    --channel unix,target.type=virtio,target.name=org.qemu.guest_agent.0 \
    --noautoconsole

echo "Aguardando DHCP..."
VM_IP=""
for _ in $(seq 1 50); do
    VM_IP=$(sudo virsh domifaddr "$VM_NAME" | awk '/ipv4/ {print $4}' | cut -d/ -f1 | head -n1 || true)
    [ -n "$VM_IP" ] && break
    sleep 3
    printf '.'
done
echo

if [ -z "$VM_IP" ]; then
    echo "VM nao obteve IP via libvirt DHCP."
    exit 1
fi
echo "VM online em $VM_IP"

echo "Aguardando qemu-guest-agent..."
for _ in $(seq 1 90); do
    if guest_agent '{"execute":"guest-ping"}' >/dev/null 2>&1; then
        echo "guest-agent ativo"
        break
    fi
    sleep 2
    printf '.'
done
echo

if ! guest_agent '{"execute":"guest-ping"}' >/dev/null 2>&1; then
    echo "qemu-guest-agent nao respondeu."
    exit 1
fi

echo "[1/8] Backend health local dentro da VM"
HEALTH_JSON=""
for _ in $(seq 1 60); do
    if HEALTH_JSON=$(guest_curl "http://127.0.0.1:8080/health" 2>/dev/null); then
        break
    fi
    sleep 2
    printf '.'
done
echo

if [ -z "$HEALTH_JSON" ]; then
    echo "Backend nao respondeu em http://127.0.0.1:8080/health dentro da VM."
    exit 1
fi
echo "$HEALTH_JSON" | jq -e '.status == "ok"' >/dev/null

echo "[2/8] Network interfaces"
IFACES_JSON=$(guest_curl "http://127.0.0.1:8080/network/interfaces")
if ! echo "$IFACES_JSON" | jq -e '.interfaces | length >= 1' >/dev/null; then
    echo "Nenhuma interface detectada pelo backend:"
    echo "$IFACES_JSON"
    exit 1
fi
# Valida normalização: pelo menos uma ethernet ou wifi
echo "$IFACES_JSON" | jq -e '.interfaces[] | select(.type == "ethernet" or .type == "wifi")' >/dev/null

echo "[3/8] Network status"
NET_STATUS_JSON=$(guest_curl "http://127.0.0.1:8080/network/status")
echo "$NET_STATUS_JSON" | jq -e 'has("connected") and has("conn_type")' >/dev/null

echo "[4/8] Kiosk/frontend servindo index"
UI_HEAD=$(guest_exec "curl -fsSI --max-time 15 http://127.0.0.1:8080/")
if ! grep -q "200 OK" <<<"$UI_HEAD"; then
    echo "$UI_HEAD"
    echo "Frontend nao retornou 200 OK."
    exit 1
fi

echo "[5/8] Hardware probe"
HARDWARE_JSON=$(guest_exec "curl -sS --max-time 15 http://127.0.0.1:8080/hardware")
if ! echo "$HARDWARE_JSON" | jq -e '.cpu.cores > 0 and (.disks | length) >= 1' >/dev/null; then
    echo "Resposta invalida de /hardware:"
    echo "$HARDWARE_JSON" | jq . 2>/dev/null || echo "$HARDWARE_JSON"
    exit 1
fi

echo "[6/8] Lista segura de discos"
DISKS_JSON=$(guest_curl "http://127.0.0.1:8080/api/disks")
echo "$DISKS_JSON" | jq -e '.[] | select(.path == "/dev/vda" and .type == "disk" and .size_bytes >= 10737418240)' >/dev/null

echo "[7/8] Dry-run rejeita alvo invalido (contrato: HTTP 422 + ok:false)"
INVALID_PLAN='{"version":1,"hostname":"iso","timezone":"America/Cuiaba","locale":"pt_BR.UTF-8","keyboard":"br-abnt2","disk":{"mode":"dry-run","target":"/dev/null","layout":"btrfs-simple","boot_mode":"uefi","profile":"single","selectedDisks":[]},"user":{"name":"admin","admin":true},"features":{}}'
# Sem -f: o backend retorna 422 (semanticamente inválido) com body {ok:false};
# -f abortaria em >=400 antes de podermos validar o corpo.
INVALID_DRY_RUN=$(guest_exec "curl -sS --max-time 15 -X POST -H 'Content-Type: application/json' --data '$INVALID_PLAN' http://127.0.0.1:8080/dry-run")
echo "$INVALID_DRY_RUN" | jq -e '.ok == false' >/dev/null

echo "[8/8] Dry-run aceita somente o disco virtual /dev/vda"
VALID_PLAN='{"version":1,"hostname":"iso","timezone":"America/Cuiaba","locale":"pt_BR.UTF-8","keyboard":"br-abnt2","disk":{"mode":"dry-run","target":"/dev/vda","layout":"btrfs-simple","boot_mode":"uefi","profile":"single","selectedDisks":["/dev/vda"]},"user":{"name":"admin","admin":true},"features":{}}'
VALID_DRY_RUN=$(guest_exec "curl -fsS --max-time 15 -X POST -H 'Content-Type: application/json' --data '$VALID_PLAN' http://127.0.0.1:8080/dry-run")
echo "$VALID_DRY_RUN" | jq -e '.ok == true' >/dev/null

if [ "$RUN_INSTALL" = true ]; then
    INSTALL_PLAN=${VALID_PLAN/\"mode\":\"dry-run\"/\"mode\":\"install\"}

    # ── PREFLIGHT DE SALVAGUARDA (para antes de qualquer escrita) ──────────────
    echo "================ PREFLIGHT DESTRUTIVO ================"
    echo "VM_NAME              : $VM_NAME"
    echo "QCOW2 (abs)          : $(readlink -f "$DISK_PATH")"
    echo "--- qemu-img info ---"
    # -U (force-share): a VM live mantém lock de escrita no disco; sem isto o
    # qemu-img falha com 'Failed to get shared "write" lock'.
    qemu-img info -U "$DISK_PATH"
    echo "--- virsh domblklist ---"
    sudo virsh domblklist "$VM_NAME" --details
    echo "--- lsblk de /dev/vda DENTRO da VM ---"
    guest_exec "lsblk -o NAME,SIZE,TYPE,MOUNTPOINT /dev/vda"

    # Guarda 1: o source de vda na VM tem de ser exatamente o QCOW2 descartável.
    VDA_SOURCE=$(sudo virsh domblklist "$VM_NAME" --details \
        | awk '$2=="disk" && $3=="vda" {print $4}')
    if [ "$VDA_SOURCE" != "$(readlink -f "$DISK_PATH")" ] && [ "$VDA_SOURCE" != "$DISK_PATH" ]; then
        echo "ABORT: /dev/vda da VM ($VDA_SOURCE) != QCOW2 descartável ($DISK_PATH)"
        exit 1
    fi
    echo "CONFIRMADO: /dev/vda == QCOW2 descartável ($VDA_SOURCE)"

    # Guarda 2: o QCOW2 vive em /tmp (área descartável do teste), nunca disco real.
    case "$VDA_SOURCE" in
        /tmp/*) : ;;
        *) echo "ABORT: QCOW2 fora de /tmp — recusado por segurança"; exit 1 ;;
    esac

    # Guarda 3: o plano só pode mirar /dev/vda; qualquer disco real do host aborta.
    if printf '%s' "$INSTALL_PLAN" | grep -qE '/dev/(nvme|sd[a-z]|disk/by-id)'; then
        echo "ABORT: plano referencia disco real do host (nvme/sd*/by-id)"; exit 1
    fi
    if ! printf '%s' "$INSTALL_PLAN" | grep -q '"target":"/dev/vda"'; then
        echo "ABORT: target do plano não é /dev/vda"; exit 1
    fi
    echo "CONFIRMADO: plano mira somente /dev/vda; nenhum disco real do host será usado."
    echo "====================================================="

    echo "[destructive-vm] Executando /install real contra /dev/vda dentro da VM descartavel"
    guest_exec "curl -fsS --max-time 30 -X POST -H 'Content-Type: application/json' --data '$INSTALL_PLAN' http://127.0.0.1:8080/install" | jq .

    echo "Monitorando /install/status..."
    INSTALL_STATUS=""
    for _ in $(seq 1 900); do
        INSTALL_STATUS=$(guest_curl "http://127.0.0.1:8080/install/status")
        running=$(echo "$INSTALL_STATUS" | jq -r '.running')
        if [ "$running" = "false" ]; then
            break
        fi
        sleep 2
    done

    echo "$INSTALL_STATUS" | jq .
    echo "$INSTALL_STATUS" | jq -e '.exitCode == 0' >/dev/null

    echo "[destructive-vm] Gate live: /api/validate-install (flag + bootloader)"
    VALIDATION=$(guest_curl "http://127.0.0.1:8080/api/validate-install")
    echo "$VALIDATION" | jq .
    echo "$VALIDATION" | jq -e '.flag_ok == true and .bootloader_ok == true' >/dev/null

    echo "[destructive-vm] Desligando VM para liberar o QCOW2..."
    sudo virsh shutdown "$VM_NAME" >/dev/null 2>&1 || true
    for _ in $(seq 1 60); do
        [ "$(sudo virsh domstate "$VM_NAME" 2>/dev/null)" = "shut off" ] && break
        sleep 2
    done
    sudo virsh destroy "$VM_NAME" >/dev/null 2>&1 || true

    echo "[destructive-vm] PROVA DE DISCO offline (antes de qualquer boot)"
    if ! inspect_qcow2_offline "$DISK_PATH"; then
        echo "PROVA DE DISCO FALHOU — QCOW2 não contém instalação. NÃO declarar PASS."
        exit 1
    fi

    echo "[destructive-vm] Boot SEM ISO: removendo CD-ROM e bootando do disco"
    sudo virsh detach-disk "$VM_NAME" sda --config >/dev/null 2>&1 || true
    : > "$SERIAL_LOG" 2>/dev/null || sudo truncate -s0 "$SERIAL_LOG" 2>/dev/null || true
    sudo virsh start "$VM_NAME"

    echo "[destructive-vm] Aguardando boot do disco (guest-agent do sistema instalado)..."
    BOOTED=false
    for _ in $(seq 1 90); do
        if guest_agent '{"execute":"guest-ping"}' >/dev/null 2>&1; then
            BOOTED=true
            break
        fi
        sleep 2
        printf '.'
    done
    echo
    if [ "$BOOTED" != true ]; then
        echo "Sistema instalado não respondeu após boot sem ISO."
        echo "Serial (procurando panic da ISO / findiso):"
        sudo tail -n 60 "$SERIAL_LOG" 2>/dev/null || true
        exit 1
    fi
    if sudo grep -qE 'findiso=|Attempted to kill init' "$SERIAL_LOG" 2>/dev/null; then
        echo "Serial revela boot da ISO (findiso/panic), não do disco. NÃO declarar PASS."
        exit 1
    fi

    echo "[destructive-vm] Teste de PERSISTÊNCIA após reboot"
    STAMP="kryonix-persist-$(date +%s)"
    guest_exec "echo $STAMP | sudo tee /var/lib/$STAMP >/dev/null && sync"
    sudo virsh reboot "$VM_NAME" >/dev/null 2>&1 || true
    sleep 5
    for _ in $(seq 1 90); do
        guest_agent '{"execute":"guest-ping"}' >/dev/null 2>&1 && break
        sleep 2
    done
    if ! guest_exec "test -f /var/lib/$STAMP && cat /var/lib/$STAMP" | grep -q "$STAMP"; then
        echo "Arquivo não persistiu após reboot. NÃO declarar PASS."
        exit 1
    fi
    echo "PERSISTÊNCIA OK: $STAMP sobreviveu ao reboot, boot a partir do disco confirmado."
else
    echo "Execucao destrutiva real pulada. Use --destructive-vm-install para rodar /install em /dev/vda dentro da VM descartavel."
fi

sudo virsh screenshot "$VM_NAME" "$SCREENSHOT_OK" >/dev/null 2>&1 || true
echo "Validacao concluida. Screenshot final: $SCREENSHOT_OK"

if [ "$CI_MODE" = false ]; then
    echo "Pressione Enter para encerrar e remover a VM..."
    read -r
fi

exit 0
