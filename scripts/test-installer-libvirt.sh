#!/usr/bin/env bash
set -e

echo "Kryonix Bare-Metal Web Installer Libvirt Sandbox"
echo "================================================"

# Define directories
IMG_DIR="/tmp/kryonix-test-images"
IMG_PATH="$IMG_DIR/test-installer.qcow2"
ISO_PATH=$(ls -t /tmp/result-iso/iso/nixos-*.iso 2>/dev/null | head -n 1)

if [ -z "$ISO_PATH" ]; then
    echo "ERROR: ISO not found in /tmp/result-iso/iso/nixos-*.iso."
    echo "Please build the ISO first before running this test."
    exit 1
fi

echo "Ensuring image directory exists..."
mkdir -p "$IMG_DIR"

echo "Creating 20G QCOW2 test disk..."
rm -f "$IMG_PATH"
qemu-img create -f qcow2 "$IMG_PATH" 20G

VM_NAME="kryonix-installer-test"

echo "Destroying old VM se ela existir..."
virsh destroy "$VM_NAME" 2>/dev/null || true
virsh undefine "$VM_NAME" 2>/dev/null || true

echo "Starting VM via virt-install..."
virt-install \
    --name "$VM_NAME" \
    --memory 4096 \
    --vcpus 2 \
    --disk path="$IMG_PATH",format=qcow2,bus=virtio \
    --cdrom "$ISO_PATH" \
    --os-variant nixos-unknown \
    --network default \
    --graphics spice \
    --noautoconsole

echo "Aguardando a VM obter um endereço IP..."
VM_IP=""
for i in {1..30}; do
    VM_IP=$(virsh domifaddr "$VM_NAME" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -n 1)
    if [ -n "$VM_IP" ]; then
        echo "IP da VM: $VM_IP"
        break
    fi
    echo -n "."
    sleep 5
done

if [ -z "$VM_IP" ]; then
    echo -e "\nFalha ao obter IP da VM. O instalador não conseguiu subir a rede ou o qemu-guest-agent não iniciou."
    exit 1
fi

echo -e "\nAguardando boot da VM e subida da API (Porta 8080) em $VM_IP..."
for i in {1..30}; do
    if curl -s http://$VM_IP:8080/health | grep -q '"status":"ok"'; then
        echo -e "\n[OK] API do instalador está online!"
        break
    fi
    echo -n "."
    sleep 5
done

echo "--------------------------------------------"
echo "Executando Fase 1: Particionamento Btrfs..."
curl -s -X POST http://$VM_IP:8080/api/partition \
     -H "Content-Type: application/json" \
     -d '{"disk": "/dev/vda"}' > /tmp/partition_log.json

if grep -q "success" /tmp/partition_log.json; then
    echo "[OK] Particionamento concluído com sucesso."
else
    echo "[ERRO] Falha no particionamento:"
    cat /tmp/partition_log.json
    exit 1
fi

echo "--------------------------------------------"
echo "Executando Fase 2: NixOS Install (pode demorar)..."
curl -s -X POST http://$VM_IP:8080/api/install \
     -H "Content-Type: application/json" \
     -d '{"locale":"pt_BR.UTF-8","keyboard":"br-abnt2","user":"admin","network":"kryonix-test"}' > /tmp/install_log.json

if grep -q "success" /tmp/install_log.json; then
    echo "[OK] Instalação do NixOS concluída!"
    echo "Resumo do log de instalação salvo em /tmp/install_log.json"
else
    echo "[ERRO] Instalação falhou:"
    cat /tmp/install_log.json
    exit 1
fi

echo "Teste finalizado. A VM $VM_NAME continua rodando no libvirt para inspeção visual se desejar."
