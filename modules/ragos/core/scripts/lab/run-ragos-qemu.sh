#!/usr/bin/env bash
# Purpose: Bootar a ISO do RAGOS em QEMU com OVMF e serial local
# Category: lab
# Safety: destructive
# Expected environment: laboratorio Linux local com QEMU e OVMF disponivel
# Requires: nix, qemu
# Notes: Cria e reutiliza discos qcow2 em VMROOT

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
VMROOT="${VMROOT:-/home/nixos/ragos-vm}"
DEFAULT_ISO_PATHS=(
  "$REPO_ROOT/result-iso/iso/ragos-installer.iso"
  "$REPO_ROOT/result/iso/ragos-installer.iso"
  "/mnt/c/Users/aguia/Documents/ragos-installer-25.11.iso"
)
OVMF_CODE="${OVMF_CODE:-/nix/store/f1xhjnsvsq0mg4jy3gf11hmnyxpbdqzd-OVMF-202602-fd/FV/OVMF_CODE.fd}"
OVMF_VARS_TEMPLATE="${OVMF_VARS_TEMPLATE:-/nix/store/f1xhjnsvsq0mg4jy3gf11hmnyxpbdqzd-OVMF-202602-fd/FV/OVMF_VARS.fd}"
GRUB_DOWN_COUNT="${GRUB_DOWN_COUNT:-0}"

if [[ -z "${ISO_PATH:-}" ]]; then
  for candidate in "${DEFAULT_ISO_PATHS[@]}"; do
    if [[ -f "$candidate" ]]; then
      ISO_PATH="$candidate"
      break
    fi
  done
fi

if [[ -z "${ISO_PATH:-}" || ! -f "$ISO_PATH" ]]; then
  printf 'ISO nao encontrada. Defina ISO_PATH ou gere a imagem em %s/result-iso.\n' "$REPO_ROOT" >&2
  exit 1
fi

mkdir -p "$VMROOT"
cp -f "$OVMF_VARS_TEMPLATE" "$VMROOT/OVMF_VARS.fd"
chmod 0644 "$VMROOT/OVMF_VARS.fd"

if [[ ! -f "$VMROOT/disk0.qcow2" ]]; then
  /run/current-system/sw/bin/nix --extra-experimental-features nix-command --extra-experimental-features flakes shell nixpkgs#qemu -c qemu-img create -f qcow2 "$VMROOT/disk0.qcow2" 80G >/dev/null
fi

if [[ ! -f "$VMROOT/disk1.qcow2" ]]; then
  /run/current-system/sw/bin/nix --extra-experimental-features nix-command --extra-experimental-features flakes shell nixpkgs#qemu -c qemu-img create -f qcow2 "$VMROOT/disk1.qcow2" 120G >/dev/null
fi

if [[ -f "$VMROOT/qemu.pid" ]] && kill -0 "$(cat "$VMROOT/qemu.pid")" 2>/dev/null; then
  kill "$(cat "$VMROOT/qemu.pid")" || true
  sleep 2
fi

rm -f "$VMROOT/serial.log" "$VMROOT/qemu.log" "$VMROOT/monitor.sock" "$VMROOT/qemu.pid"

/run/current-system/sw/bin/nix --extra-experimental-features nix-command --extra-experimental-features flakes shell nixpkgs#qemu -c \
  qemu-system-x86_64 \
  -name ragos-iso-test \
  -machine q35,accel=tcg \
  -m 4096 -smp 2 \
  -cpu max \
  -daemonize \
  -pidfile "$VMROOT/qemu.pid" \
  -D "$VMROOT/qemu.log" \
  -monitor "unix:$VMROOT/monitor.sock,server,nowait" \
  -serial "file:$VMROOT/serial.log" \
  -display none \
  -device virtio-vga \
  -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE" \
  -drive "if=pflash,format=raw,file=$VMROOT/OVMF_VARS.fd" \
  -boot order=d \
  -drive "file=$ISO_PATH,media=cdrom,if=ide,index=0" \
  -drive "file=$VMROOT/disk0.qcow2,if=virtio,format=qcow2" \
  -drive "file=$VMROOT/disk1.qcow2,if=virtio,format=qcow2" \
  -netdev "user,id=mgmt,net=10.10.0.0/24,dhcpstart=10.10.0.20,hostfwd=tcp::10022-:22,hostfwd=tcp::18000-:8000" \
  -device "virtio-net-pci,netdev=mgmt,mac=52:54:00:10:10:10" \
  -netdev "user,id=wan,net=10.20.0.0/24,dhcpstart=10.20.0.20" \
  -device "virtio-net-pci,netdev=wan,mac=52:54:00:20:20:20"

if [[ "$GRUB_DOWN_COUNT" =~ ^[0-9]+$ ]] && (( GRUB_DOWN_COUNT > 0 )); then
  sleep 2
  for _ in $(seq 1 "$GRUB_DOWN_COUNT"); do
    printf 'sendkey down\n' | /run/current-system/sw/bin/nix --extra-experimental-features nix-command --extra-experimental-features flakes shell nixpkgs#socat -c socat - "UNIX-CONNECT:$VMROOT/monitor.sock" >/dev/null
    sleep 0.2
  done
  printf 'sendkey ret\n' | /run/current-system/sw/bin/nix --extra-experimental-features nix-command --extra-experimental-features flakes shell nixpkgs#socat -c socat - "UNIX-CONNECT:$VMROOT/monitor.sock" >/dev/null
fi

cat "$VMROOT/qemu.pid"
