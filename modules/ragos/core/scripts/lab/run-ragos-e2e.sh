#!/usr/bin/env bash
# Purpose: Executar um fluxo end-to-end de instalacao e boot em QEMU
# Category: lab
# Safety: destructive
# Expected environment: laboratorio Linux local com QEMU, Nix e sshpass
# Requires: nix, qemu, openssh, sshpass
# Notes: Reutiliza caminhos e credenciais de laboratorio

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
DIRECT_VMROOT="${DIRECT_VMROOT:-/home/nixos/ragos-vm-direct}"
DISK_VMROOT="${DISK_VMROOT:-/home/nixos/ragos-vm-disk}"
LAB_ADMIN_PASSWORD="${LAB_ADMIN_PASSWORD:-Ragos!2026Think}"

log() {
  printf '\n[%s] %s\n' "$(date +%H:%M:%S)" "$*"
}

show_log_context() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  tail -n 200 "$file" || true
}

serial_has_emergency() {
  local file="$1"
  grep -Eiq 'emergency mode|Welcome to emergency mode|You are in emergency mode|emergency.target|rescue.target|Entering emergency mode' "$file" 2>/dev/null
}

fail_on_emergency_log() {
  local file="$1" context="$2"
  if serial_has_emergency "$file"; then
    log "Falha detectada no serial durante $context"
    show_log_context "$file"
    exit 1
  fi
}

wait_for_log() {
  local file="$1"
  local pattern="$2"
  local timeout="${3:-600}"
  local waited=0
  while (( waited < timeout )); do
    if grep -q "$pattern" "$file" 2>/dev/null; then
      return 0
    fi
    sleep 5
    waited=$(( waited + 5 ))
  done
  return 1
}

cd "$REPO_ROOT"

log "Bootando live ISO em console serial"
bash scripts/lab/run-ragos-qemu-direct.sh >/tmp/ragos-live.pid
LIVE_PID="$(cat /tmp/ragos-live.pid)"
log "PID live: $LIVE_PID"

wait_for_log "$DIRECT_VMROOT/serial.log" "Multi-User System" 900
wait_for_log "$DIRECT_VMROOT/serial.log" "bash-5.3\\$" 900
log "Live system pronto; disparando instalacao unattended"

SERIAL_COMMAND_FILE=scripts/lab/install-live.commands SERIAL_COMMAND_SETTLE_SECONDS=20 bash scripts/lab/send-ragos-serial.sh

if ! wait_for_log "$DIRECT_VMROOT/serial.log" "Instala" 3600; then
  log "Nenhum marcador de conclusao encontrado; exibindo ultimas linhas"
  tail -n 200 "$DIRECT_VMROOT/serial.log"
  exit 1
fi

if grep -q "ERRO:" "$DIRECT_VMROOT/serial.log"; then
  log "Instalador reportou erro"
  tail -n 200 "$DIRECT_VMROOT/serial.log"
  exit 1
fi

if ! grep -q "Instala" "$DIRECT_VMROOT/serial.log"; then
  log "Instalacao nao concluiu"
  tail -n 200 "$DIRECT_VMROOT/serial.log"
  exit 1
fi

log "Parando live e bootando sistema instalado"
kill "$LIVE_PID" || true
sleep 5

mkdir -p "$DISK_VMROOT"
OVMF_FD="${OVMF_FD:-$(nix path-info nixpkgs#OVMF 2>/dev/null)/FV}"
[[ -d "$OVMF_FD" ]] || OVMF_FD="/nix/store/zp51g43pr03sisri6xs1nyba6j2ad5kc-OVMF-202602-fd/FV"
cp -f "$OVMF_FD/OVMF_VARS.fd" "$DISK_VMROOT/OVMF_VARS.fd"
chmod 0644 "$DISK_VMROOT/OVMF_VARS.fd"
rm -f "$DISK_VMROOT/qemu.log" "$DISK_VMROOT/qemu.pid" "$DISK_VMROOT/serial.log"

/run/current-system/sw/bin/nix --extra-experimental-features nix-command --extra-experimental-features flakes shell nixpkgs#qemu -c \
  qemu-system-x86_64 \
  -name ragos-installed-test \
  -machine q35,accel=tcg \
  -m 4096 -smp 2 \
  -cpu max \
  -daemonize \
  -pidfile "$DISK_VMROOT/qemu.pid" \
  -D "$DISK_VMROOT/qemu.log" \
  -serial "file:$DISK_VMROOT/serial.log" \
  -display none \
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_FD/OVMF_CODE.fd" \
  -drive if=pflash,format=raw,file="$DISK_VMROOT/OVMF_VARS.fd" \
  -boot order=c \
  -drive "file=$DIRECT_VMROOT/disk0.qcow2,if=virtio,format=qcow2" \
  -drive "file=$DIRECT_VMROOT/disk1.qcow2,if=virtio,format=qcow2" \
  -netdev "user,id=mgmt,net=10.10.0.0/24,dhcpstart=10.10.0.20,hostfwd=tcp::12022-:22" \
  -device "virtio-net-pci,netdev=mgmt,mac=52:54:00:10:10:11" \
  -netdev "user,id=wan,net=10.20.0.0/24,dhcpstart=10.20.0.20" \
  -device "virtio-net-pci,netdev=wan,mac=52:54:00:20:20:21"

waited=0
until /run/current-system/sw/bin/nix --extra-experimental-features nix-command --extra-experimental-features flakes shell nixpkgs#sshpass nixpkgs#openssh -c \
sshpass -p "$LAB_ADMIN_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -p 12022 admin@127.0.0.1 'hostname' >/tmp/ragos-ssh.txt 2>/tmp/ragos-ssh.err; do
  fail_on_emergency_log "$DISK_VMROOT/serial.log" "boot do sistema instalado"
  sleep 10
  waited=$(( waited + 10 ))
  if (( waited >= 900 )); then
    log "SSH do sistema instalado nao respondeu"
    cat /tmp/ragos-ssh.err || true
    show_log_context "$DISK_VMROOT/serial.log"
    exit 1
  fi
done

log "Sistema instalado respondeu por SSH"
if ! /run/current-system/sw/bin/nix --extra-experimental-features nix-command --extra-experimental-features flakes shell nixpkgs#sshpass nixpkgs#openssh -c \
  sshpass -p "$LAB_ADMIN_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 12022 admin@127.0.0.1 'set -euo pipefail
hostname | grep -Fx "srv-rag"
sudo systemctl is-active sshd nginx dnsmasq nfs-server
! sudo systemctl is-active --quiet emergency.target
! sudo systemctl is-active --quiet rescue.target
[[ -z "$(sudo systemctl --failed --plain --no-legend)" ]]
sudo findmnt /boot
sudo findmnt /nix
sudo findmnt /srv
sudo findmnt /srv/data/home
sudo findmnt /srv/data/images
sudo findmnt /srv/data/snapshots
sudo systemctl is-active boot.mount nix.mount srv.mount srv-data-home.mount srv-data-images.mount srv-data-snapshots.mount
grep -E '\''dataDisk = "/dev/disk/by-(label|uuid)/'\'' /etc/ragos/server/runtime/params.nix
! grep -E '\''dataDisk = "/dev/(sd|vd|xvd|hd)'\'' /etc/ragos/server/runtime/params.nix
sudo nixos-rebuild switch --flake /etc/nixos/ragos#srv-rag'; then
  /run/current-system/sw/bin/nix --extra-experimental-features nix-command --extra-experimental-features flakes shell nixpkgs#sshpass nixpkgs#openssh -c \
  sshpass -p "$LAB_ADMIN_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 12022 admin@127.0.0.1 'sudo systemctl --failed --plain --no-legend || true; sudo journalctl -b -p err --no-pager | tail -n 50 || true; sudo findmnt /boot /nix /srv /srv/data/home /srv/data/images /srv/data/snapshots || true; grep -n "dataDisk" /etc/ragos/server/runtime/params.nix || true' || true
  fail_on_emergency_log "$DISK_VMROOT/serial.log" "validacao estrita"
  exit 1
fi

fail_on_emergency_log "$DISK_VMROOT/serial.log" "validacao estrita"
log "E2E concluido"
