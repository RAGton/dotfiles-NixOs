#!/usr/bin/env bash
set -e

echo "Kryonix Bare-Metal Web Installer KVM Sandbox"
echo "============================================"

# Define directories
IMG_DIR="/srv/ragenterprise/images"
IMG_PATH="$IMG_DIR/test-installer.img"
ISO_PATH=$(ls -t result/iso/nixos-*.iso 2>/dev/null | head -n 1)

if [ -z "$ISO_PATH" ]; then
    echo "ERROR: ISO not found in result/iso/nixos-*.iso."
    echo "Please build the ISO first before running this test."
    exit 1
fi

echo "Ensuring image directory exists..."
sudo mkdir -p "$IMG_DIR"
sudo chown -R $USER:$USER "$IMG_DIR"

echo "Creating 20G QCOW2 test disk..."
rm -f "$IMG_PATH"
qemu-img create -f qcow2 "$IMG_PATH" 20G

echo "Starting KVM..."
echo " - ISO: $ISO_PATH"
echo " - Disk: $IMG_PATH"
echo " - RAM: 4G"
echo " - Port Forward: 8080 (Installer API) -> 8080"
echo "============================================"

# Inicia o QEMU em background (ou daemonizado) sem bloquear o terminal
echo "Subindo KVM em background..."
qemu-system-x86_64 \
    -enable-kvm \
    -m 4G \
    -smp 2 \
    -machine q35 \
    -cdrom "$ISO_PATH" \
    -drive file="$IMG_PATH",format=qcow2,if=virtio \
    -netdev user,id=net0,hostfwd=tcp::8080-:8080,hostfwd=tcp::2222-:22 \
    -device virtio-net-pci,netdev=net0 \
    -display none \
    -daemonize

echo "Aguardando boot da VM e subida da API (Porta 8080)..."
for i in {1..30}; do
    if curl -s http://localhost:8080/health | grep -q '"status":"ok"'; then
        echo -e "\n[OK] API do instalador está online!"
        break
    fi
    echo -n "."
    sleep 5
done

echo "--------------------------------------------"
echo "Executando Fase 1: Particionamento Btrfs..."
curl -s -X POST http://localhost:8080/api/partition \
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
curl -s -X POST http://localhost:8080/api/install > /tmp/install_log.json

if grep -q "success" /tmp/install_log.json; then
    echo "[OK] Instalação do NixOS concluída!"
    echo "Resumo do log de instalação salvo em /tmp/install_log.json"
else
    echo "[ERRO] Instalação falhou:"
    cat /tmp/install_log.json
    exit 1
fi

echo "--------------------------------------------"
echo "Instalação atômica finalizada. Desligando VM de teste..."
# Desliga a VM
killall qemu-system-x86_64 || true
echo "Teste finalizado."

