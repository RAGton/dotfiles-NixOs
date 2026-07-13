#!/usr/bin/env bash
# Purpose: Enviar comandos de probe para o console serial da VM de laboratorio
# Category: lab
# Safety: lab-only
# Expected environment: laboratorio local com socket serial de QEMU
# Requires: bash, socat

set -euo pipefail

VMROOT="${VMROOT:-/home/nixos/ragos-vm-direct}"
SERIAL_SOCK="${SERIAL_SOCK:-$VMROOT/serial.sock}"

sleep "${SERIAL_WAIT_SECONDS:-0}"

{
  sleep 1
  printf '\n'
  sleep 1
  printf 'echo LIVE_PROBE\n'
  sleep 1
  printf 'id\n'
  sleep 1
  printf 'systemctl is-active ragos-installer-ui\n'
  sleep 1
  printf 'ls /opt\n'
  sleep 1
  printf 'ls /opt/ragos-src >/dev/null && echo HAVE_REPO\n'
  sleep 1
  printf 'curl -fsS http://127.0.0.1:8000/api/v1/status\n'
  sleep 3
} | /run/current-system/sw/bin/nix --extra-experimental-features nix-command --extra-experimental-features flakes shell nixpkgs#socat -c \
  socat - "UNIX-CONNECT:$SERIAL_SOCK"
