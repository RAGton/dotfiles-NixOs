#!/usr/bin/env bash
# Test script for Kryonix ISO boot and installer availability
# Requires: qemu-system-x86_64, curl

set -e

ISO_PATH="${1:-result/iso/kryonix.iso}"
DISK_PATH="/tmp/kryonix-test-disk.qcow2"

if [ ! -f "$ISO_PATH" ]; then
    echo "❌ ISO not found at $ISO_PATH. Build it first with 'kryonix build iso'."
    exit 1
fi

echo "🚀 Creating 32GB test disk..."
rm -f "$DISK_PATH"
qemu-img create -f qcow2 "$DISK_PATH" 32G

# Check for CI flag
CI_MODE=false
if [[ "$*" == *"--ci"* ]]; then
    CI_MODE=true
    echo "🤖 Running in CI mode (non-interactive)"
fi

QEMU_FLAGS="-m 4G -smp 2"
# Check if KVM is available
if [ -e /dev/kvm ] && [ -w /dev/kvm ]; then
    echo "⚡ KVM is available, enabling hardware acceleration."
    QEMU_FLAGS="$QEMU_FLAGS -enable-kvm -cpu host"
else
    echo "⚠️ KVM not found or not writable. Running with software emulation (slow)."
    QEMU_FLAGS="$QEMU_FLAGS -cpu core2duo"
fi

echo "🖥️ Starting VM (UEFI mode)..."
echo "Note: The installer API will be forwarded to localhost:8080"

# Note: Using standard OVMF paths for NixOS/Linux
OVMF_CODE="/usr/share/OVMF/OVMF_CODE.fd"
if [ ! -f "$OVMF_CODE" ]; then
    # Fallback for common locations
    OVMF_CODE=$(find /nix/store -name "OVMF_CODE.fd" | head -n 1)
fi

qemu-system-x86_64 \
    $QEMU_FLAGS \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive file="$DISK_PATH",format=qcow2 \
    -cdrom "$ISO_PATH" \
    -net nic,model=virtio \
    -net user,hostfwd=tcp::8080-:8080 \
    -display none \
    -vga virtio \
    -device virtio-tablet-pci \
    -serial stdio &

VM_PID=$!

echo "⏳ Waiting for installer API to respond..."
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:8080/health > /dev/null; then
        echo "✅ Installer API is UP!"
        curl -s http://localhost:8080/health | jq .
        break
    fi
    echo -n "."
    sleep 5
    RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "❌ Timeout waiting for installer API."
    kill $VM_PID
    exit 1
fi

echo "🎯 Test successful. VM is running with PID $VM_PID."

if [ "$CI_MODE" = true ]; then
    echo "✅ CI check passed. Shutting down VM."
    kill $VM_PID
    rm -f "$DISK_PATH"
    exit 0
fi

echo "You can now access the installer UI at http://localhost:8080"
echo "Press Enter to stop the VM."
read
kill $VM_PID
rm -f "$DISK_PATH"
