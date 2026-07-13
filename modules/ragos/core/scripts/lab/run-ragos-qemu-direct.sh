#!/usr/bin/env bash
# Purpose: Bootar kernel/initrd extraidos da ISO em uma VM QEMU de laboratorio
# Category: lab
# Safety: destructive
# Expected environment: laboratorio Linux local com QEMU e artefatos de ISO
# Requires: nix, qemu, xorriso
# Notes: Cria e reutiliza discos qcow2 em VMROOT

set -euo pipefail

VMROOT="${VMROOT:-/home/nixos/ragos-vm-direct}"
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
LIVE_SSH_PORT="${LIVE_SSH_PORT:-11022}"
API_PORT="${API_PORT:-19000}"
DEFAULT_ISO_PATHS=(
  "$REPO_ROOT/result-iso/iso/ragos-installer.iso"
  "$REPO_ROOT/result/iso/ragos-installer.iso"
)
if [[ -z "${ISO_PATH:-}" ]]; then
  for candidate in "${DEFAULT_ISO_PATHS[@]}"; do
    if [[ -f "$candidate" ]]; then
      ISO_PATH="$candidate"
      break
    fi
  done
  if [[ -z "${ISO_PATH:-}" ]]; then
    ISO_PATH="/mnt/c/Users/aguia/OneDrive/Documents/ragos-installer.iso"
  fi
fi
GRUB_CFG="$VMROOT/grub.cfg"

if [[ ! -f "$ISO_PATH" ]]; then
  printf 'ISO nao encontrada em %s\n' "$ISO_PATH" >&2
  exit 1
fi

mkdir -p "$VMROOT"

/run/current-system/sw/bin/nix --extra-experimental-features nix-command --extra-experimental-features flakes shell nixpkgs#xorriso -c \
  xorriso -osirrox on -indev "$ISO_PATH" -extract /EFI/BOOT/grub.cfg "$GRUB_CFG" >/dev/null 2>&1

readarray -t BOOT_LINES < <(/run/current-system/sw/bin/nix --extra-experimental-features nix-command --extra-experimental-features flakes shell nixpkgs#python3 -c python3 - "$GRUB_CFG" <<'PY'
import re
import sys
from pathlib import Path

cfg = Path(sys.argv[1]).read_text()
needles = [
    "menuentry 'Install RAGOS (Terminal) '",
    "menuentry 'Install RAGOS (Terminal UI, Serial Console) '",
]
idx = -1
for needle in needles:
    idx = cfg.find(needle)
    if idx >= 0:
        break
if idx < 0:
    raise SystemExit("terminal menuentry not found")
block = cfg[idx:].split("}\n", 1)[0]
linux = re.search(r"^\s*linux\s+(\S+)\s+(.*)$", block, re.M)
initrd = re.search(r"^\s*initrd\s+(\S+)\s*$", block, re.M)
if not linux or not initrd:
    raise SystemExit("linux/initrd lines not found")
print(linux.group(1))
print(linux.group(2))
print(initrd.group(1))
PY
)

KERNEL_PATH="${BOOT_LINES[0]}"
APPEND_LINE="${BOOT_LINES[1]}"
INITRD_PATH="${BOOT_LINES[2]}"

/run/current-system/sw/bin/nix --extra-experimental-features nix-command --extra-experimental-features flakes shell nixpkgs#xorriso -c \
  xorriso -osirrox on -indev "$ISO_PATH" -extract "$KERNEL_PATH" "$VMROOT/bzImage" >/dev/null 2>&1
/run/current-system/sw/bin/nix --extra-experimental-features nix-command --extra-experimental-features flakes shell nixpkgs#xorriso -c \
  xorriso -osirrox on -indev "$ISO_PATH" -extract "$INITRD_PATH" "$VMROOT/initrd" >/dev/null 2>&1

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

rm -f "$VMROOT/serial.log" "$VMROOT/serial.sock" "$VMROOT/qemu.log" "$VMROOT/qemu.pid"

/run/current-system/sw/bin/nix --extra-experimental-features nix-command --extra-experimental-features flakes shell nixpkgs#qemu -c \
  qemu-system-x86_64 \
  -name ragos-iso-direct \
  -machine q35,accel=tcg \
  -m 4096 -smp 2 \
  -cpu max \
  -daemonize \
  -pidfile "$VMROOT/qemu.pid" \
  -D "$VMROOT/qemu.log" \
  -display none \
  -chardev "socket,id=charserial,path=$VMROOT/serial.sock,server=on,wait=off,logfile=$VMROOT/serial.log,signal=off" \
  -serial "chardev:charserial" \
  -kernel "$VMROOT/bzImage" \
  -initrd "$VMROOT/initrd" \
  -append "$APPEND_LINE" \
  -drive "file=$ISO_PATH,media=cdrom,if=ide,index=0" \
  -drive "file=$VMROOT/disk0.qcow2,if=virtio,format=qcow2" \
  -drive "file=$VMROOT/disk1.qcow2,if=virtio,format=qcow2" \
  -netdev "user,id=mgmt,net=10.10.0.0/24,dhcpstart=10.10.0.20,hostfwd=tcp::$LIVE_SSH_PORT-:22,hostfwd=tcp::$API_PORT-:8000" \
  -device "virtio-net-pci,netdev=mgmt,mac=52:54:00:10:10:11" \
  -netdev "user,id=wan,net=10.20.0.0/24,dhcpstart=10.20.0.20" \
  -device "virtio-net-pci,netdev=wan,mac=52:54:00:20:20:21"

cat "$VMROOT/qemu.pid"
