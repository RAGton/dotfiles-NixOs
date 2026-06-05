#!/usr/bin/env bash
# ==============================================================================
# Kryonix ISO Boot Validation
# ==============================================================================
set -euo pipefail

# Configurações
FLAKE_TARGET=".#nixosConfigurations.iso.config.system.build.isoImage"
OUT_LINK="result-iso"
VM_MEM="4G"
VM_CPUS="4"

echo "--- 1. Construindo ISO Kryonix ---"
nix build "$FLAKE_TARGET" --out-link "$OUT_LINK"

ISO_PATH=$(find "$OUT_LINK/iso" -name "*.iso" | head -n 1)

if [ -z "$ISO_PATH" ]; then
    echo "ERRO: ISO não encontrada em $OUT_LINK/iso"
    exit 1
fi

echo "ISO Gerada: $ISO_PATH"

echo "--- 2. Iniciando QEMU para validação ---"
echo "Dica: o instalador deve abrir automaticamente no modo Kiosk."

# Rodar QEMU com virtio-gpu e rede
# -net user,hostfwd=tcp::8080-:8080 permite acessar o backend do host
# -m 4G para aguentar o Chromium no Cage
qemu-kvm \
    -m "$VM_MEM" \
    -smp "$VM_CPUS" \
    -drive "file=$ISO_PATH,format=raw,readonly=on" \
    -device virtio-gpu-pci \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::8080-:8080 \
    -display gtk,gl=on \
    -vga none \
    -serial stdio
