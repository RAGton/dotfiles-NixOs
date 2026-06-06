#!/usr/bin/env bash
set -eou pipefail

QCOW2_IMAGE="${1:-disk.qcow2}"
MOUNT_DIR=$(mktemp -d)

if ! command -v qemu-nbd &> /dev/null; then
    echo "Error: qemu-nbd is not installed. Please run on a system with qemu-utils."
    exit 1
fi

# Cleanup on exit
cleanup() {
    echo "Unmounting QCOW2..."
    umount -R "$MOUNT_DIR" 2>/dev/null || true
    qemu-nbd --disconnect /dev/nbd0 2>/dev/null || true
    rm -rf "$MOUNT_DIR"
}
trap cleanup EXIT

echo "Connecting $QCOW2_IMAGE via qemu-nbd..."
modprobe nbd max_part=8 || true
qemu-nbd --connect=/dev/nbd0 "$QCOW2_IMAGE" --read-only

# Wait for partitions to show up
sleep 2

# We expect a btrfs root partition and a vfat boot partition
ROOT_PART=$(lsblk -rn -o NAME,FSTYPE /dev/nbd0 | grep -i btrfs | awk '{print $1}' | head -n 1 || true)
BOOT_PART=$(lsblk -rn -o NAME,FSTYPE /dev/nbd0 | grep -i vfat | awk '{print $1}' | head -n 1 || true)

if [ -z "$ROOT_PART" ]; then
    echo "FAIL: Could not find BTRFS root partition on $QCOW2_IMAGE."
    exit 1
fi

echo "Mounting root (/dev/$ROOT_PART) to $MOUNT_DIR..."
mount -o ro "/dev/$ROOT_PART" "$MOUNT_DIR"

if [ -n "$BOOT_PART" ]; then
    echo "Mounting boot (/dev/$BOOT_PART) to $MOUNT_DIR/boot..."
    mkdir -p "$MOUNT_DIR/boot"
    mount -o ro "/dev/$BOOT_PART" "$MOUNT_DIR/boot"
else
    echo "WARN: No VFAT partition found for /boot."
fi

echo "Validating offline QCOW2 files..."

FAIL=0

check_exists() {
    if [ ! -e "$MOUNT_DIR/$1" ]; then
        echo "FAIL: $1 missing"
        FAIL=1
    else
        echo "PASS: $1 exists"
    fi
}

# 1. /etc/kryonix/flake.nix
check_exists "etc/kryonix/flake.nix"

# 2. /etc/kryonixos/flake.nix
check_exists "etc/kryonixos/flake.nix"

# 3. Host configuration files
check_exists "etc/kryonixos/hosts/kryonix-e2e/default.nix"
check_exists "etc/kryonixos/hosts/kryonix-e2e/hardware-configuration.nix"
check_exists "etc/kryonixos/hosts/kryonix-e2e/disks.nix"

# 4. State files
check_exists "etc/kryonix-installed"

# 5. /nix/store populated
if [ -d "$MOUNT_DIR/nix/store" ]; then
    STORE_COUNT=$(ls -1q "$MOUNT_DIR/nix/store" | wc -l)
    if [ "$STORE_COUNT" -lt 50 ]; then
        echo "FAIL: /nix/store appears mostly empty ($STORE_COUNT items)"
        FAIL=1
    else
        echo "PASS: /nix/store is populated ($STORE_COUNT items)"
    fi
else
    echo "FAIL: /nix/store missing"
    FAIL=1
fi

# 6. /boot with EFI
if [ -d "$MOUNT_DIR/boot/EFI" ] || [ -d "$MOUNT_DIR/boot/grub" ] || [ -d "$MOUNT_DIR/boot/loader" ]; then
    echo "PASS: /boot has EFI/loader/grub"
else
    echo "FAIL: /boot missing EFI/loader/grub"
    FAIL=1
fi

# Explicit check for bad symlink (engine)
if [ -e "$MOUNT_DIR/etc/kryonixos/engine" ]; then
    if [ -L "$MOUNT_DIR/etc/kryonixos/engine" ]; then
        echo "FAIL: /etc/kryonixos/engine is a symlink. It must not exist or not be a symlink to Live ISO."
        FAIL=1
    else
        echo "WARN: /etc/kryonixos/engine exists but is not a symlink. We expect it to not exist anymore (we use /etc/kryonix now)."
    fi
fi

if [ "$FAIL" -eq 1 ]; then
    echo "Validation failed."
    exit 1
else
    echo "All offline validations passed."
    exit 0
fi
