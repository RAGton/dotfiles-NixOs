#!/usr/bin/env bash
# Kryonix ISO Advanced Stress Test & Integrity Validation (Libvirt/QEMU)
# Autor: Gabriel Aguiar Rocha (RAGton) + Gemini CLI
# Data: 2026-05-31
# Requires: libvirt-daemon-system, virtinst, qemu-kvm, curl, jq

set -euo pipefail

# Configurações de Path
ISO_PATH="${1:-result/iso/kryonix.iso}"
if [ ! -f "$ISO_PATH" ]; then
    echo "❌ ISO não encontrada em $ISO_PATH. Execute 'kryonix build iso' primeiro."
    exit 1
fi

VM_NAME="kryonix-stress-$(date +%s)"
DISK_PATH="/tmp/$VM_NAME-target.qcow2"
SERIAL_LOG="/tmp/$VM_NAME-serial.log"
SCREENSHOT_ERR="/tmp/$VM_NAME-error.ppm"
SCREENSHOT_OK="/tmp/$VM_NAME-success.ppm"
SSE_LOG="/tmp/$VM_NAME-sse.log"
KIOSK_LOG="/tmp/$VM_NAME-kiosk.log"

# Check for CI flag
CI_MODE=false
if [[ "$*" == *"--ci"* ]]; then
    CI_MODE=true
    echo "🤖 Executando em modo CI (não interativo)"
fi

echo "🧹 Preparando ambiente efêmero..."
rm -f "$DISK_PATH" "$SERIAL_LOG" "$SCREENSHOT_ERR" "$SCREENSHOT_OK" "$SSE_LOG" "$KIOSK_LOG"
qemu-img create -f qcow2 "$DISK_PATH" 32G > /dev/null

cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "🚨 FALHA NA VALIDAÇÃO. Capturando evidências técnicas..."
        
        # Screenshot de erro
        sudo virsh screenshot "$VM_NAME" "$SCREENSHOT_ERR" >/dev/null 2>&1 || true
        echo "📸 Screenshot de erro salvo em $SCREENSHOT_ERR"
        
        # Extração de logs do Kiosk se a API estiver disponível
        if [ -n "${VM_IP:-}" ]; then
            echo "🔍 Tentando extrair logs do Kiosk via Journald (remoto)..."
            # Como não temos SSH garantido, tentamos via console ou deixamos para o serial dump
        fi

        echo "📄 Dump do Console Serial (últimas 100 linhas):"
        tail -n 100 "$SERIAL_LOG" 2>/dev/null || true
    fi
    
    echo "🧹 Destruindo VM efêmera e limpando discos..."
    sudo virsh destroy "$VM_NAME" >/dev/null 2>&1 || true
    sudo virsh undefine "$VM_NAME" --remove-all-storage >/dev/null 2>&1 || true
    rm -f "$DISK_PATH" "$SERIAL_LOG" "$SSE_LOG" "$KIOSK_LOG"
    exit $exit_code
}
trap cleanup EXIT

# Inicia rede libvirt se necessário
if ! sudo virsh net-info default | grep -q 'Active:.*yes'; then
    sudo virsh net-start default >/dev/null 2>&1 || true
fi

echo "🖥️ Provisionando VM via virt-install..."
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
    --noautoconsole

echo "⏳ Aguardando IP da VM (DHCP)..."
VM_IP=""
for i in {1..50}; do
    VM_IP=$(sudo virsh domifaddr "$VM_NAME" | grep ipv4 | awk '{print $4}' | cut -d'/' -f1 | head -n1 || true)
    if [ -n "$VM_IP" ]; then break; fi
    sleep 3
    echo -n "."
done

if [ -z "$VM_IP" ]; then
    echo -e "\n❌ Erro: VM não obteve IP. O boot falhou ou Plymouth travou."
    exit 1
fi
echo -e "\n✅ VM Online: $VM_IP"

# ==============================================================================
# BATERIA DE TESTES INDUSTRIAIS
# ==============================================================================

echo "🧪 [1/5] Teste de Renderização UI (Kiosk)"
# Verifica se o index.html e assets estão sendo servidos
UI_RESP=$(curl -s -I "http://$VM_IP:8080/")
if ! echo "$UI_RESP" | grep -q "200 OK"; then
    echo "❌ Kiosk UI não está servindo arquivos estáticos."
    exit 1
fi
echo "✅ UI servida com sucesso (Vite/React dist)."


echo "🧪 [2/5] Validação de Hardware Probe (Integridade JSON)"
HARDWARE_JSON=$(curl -s "http://$VM_IP:8080/hardware")
# Valida se contém CPU e pelo menos 1 disco (o virtual de 32GB)
CPU_COUNT=$(echo "$HARDWARE_JSON" | jq '.cpu | length' 2>/dev/null || echo "0")
DISK_COUNT=$(echo "$HARDWARE_JSON" | jq '.disks | length' 2>/dev/null || echo "0")

if [ "$CPU_COUNT" -eq 0 ] || [ "$DISK_COUNT" -eq 0 ]; then
    echo "❌ Hardware Probe retornou dados incompletos: $HARDWARE_JSON"
    exit 1
fi
echo "✅ Hardware detectado: $CPU_COUNT CPUs e $DISK_COUNT discos."


echo "🧪 [3/5] Teste de Particionamento (Dry-Run)"
DRY_RUN=$(curl -s -X POST -H "Content-Type: application/json" \
    -d '{"host": "inspiron", "device": "/dev/vda", "scheme": "btrfs", "dry_run": true}' \
    "http://$VM_IP:8080/disk/apply")

if ! echo "$DRY_RUN" | grep -q '"status":"dry-run"'; then
    echo "❌ Erro no Dry-Run do Disko: $DRY_RUN"
    exit 1
fi
echo "✅ Configuração BTRFS validada logicamente."


echo "🧪 [4/5] Execução de Formatação Real"
APPLY=$(curl -s -X POST -H "Content-Type: application/json" \
    -d '{"host": "inspiron", "device": "/dev/vda", "scheme": "btrfs", "dry_run": false}' \
    "http://$VM_IP:8080/disk/apply")

if ! echo "$APPLY" | grep -q '"status":"success"'; then
    echo "❌ Falha crítica na formatação real: $APPLY"
    exit 1
fi
echo "✅ Disco /dev/vda particionado e formatado."


echo "🧪 [5/5] Orquestração e Integridade da Instalação"
curl -s -X POST -H "Content-Type: application/json" \
    -d '{"host": "inspiron"}' \
    "http://$VM_IP:8080/install/finalize" > /dev/null

echo "📡 Monitorando SSE (Timeout 15min)..."
curl -s -N "http://$VM_IP:8080/install/progress" > "$SSE_LOG" &
SSE_PID=$!

INSTALLED=false
for i in {1..450}; do
    if grep -q '"step":"done"' "$SSE_LOG" 2>/dev/null; then
        INSTALLED=true
        break
    elif grep -q '"step":"error"' "$SSE_LOG" 2>/dev/null; then
        break
    fi
    sleep 2
done
kill $SSE_PID 2>/dev/null || true

if [ "$INSTALLED" = false ]; then
    echo "❌ A instalação falhou ou expirou o tempo limite."
    exit 1
fi

# Validação final de arquivos via API
VALIDATION=$(curl -s "http://$VM_IP:8080/api/validate-install")
FLAG_OK=$(echo "$VALIDATION" | jq -r '.flag_ok')
BOOT_OK=$(echo "$VALIDATION" | jq -r '.bootloader_ok')

if [ "$FLAG_OK" != "true" ] || [ "$BOOT_OK" != "true" ]; then
    echo "❌ Falha na integridade pós-instalação: $VALIDATION"
    exit 1
fi
echo "✅ Integridade validada: Flag e Bootloader detectados em /mnt."

# Screenshot final de sucesso
sudo virsh screenshot "$VM_NAME" "$SCREENSHOT_OK" >/dev/null 2>&1 || true
echo "🎉 STRESS TEST PASSOU! Screenshot final salvo em $SCREENSHOT_OK"

if [ "$CI_MODE" = false ]; then
    echo "Pressione Enter para encerrar..."
    read -r
fi

exit 0
