#!/usr/bin/env bash
# Purpose: Enviar comandos para o console serial da VM de laboratorio
# Category: lab
# Safety: destructive
# Expected environment: laboratorio local com socket serial de QEMU
# Requires: bash, socat
# Notes: Pode executar comandos arbitrarios no guest

set -euo pipefail

VMROOT="${VMROOT:-/home/nixos/ragos-vm-direct}"
SERIAL_SOCK="${SERIAL_SOCK:-$VMROOT/serial.sock}"

if [[ -n "${SERIAL_COMMAND_FILE:-}" ]]; then
  payload_file="$SERIAL_COMMAND_FILE"
elif [[ -n "${SERIAL_COMMAND:-}" ]]; then
  command_text="$SERIAL_COMMAND"
elif (( $# == 0 )); then
  echo "usage: $0 <command...>" >&2
  exit 2
else
  command_text="$*"
fi

if [[ -n "${payload_file:-}" ]]; then
  {
    sleep 1
    cat "$payload_file"
    sleep "${SERIAL_COMMAND_SETTLE_SECONDS:-2}"
  } | /run/current-system/sw/bin/nix --extra-experimental-features nix-command --extra-experimental-features flakes shell nixpkgs#socat -c \
    socat - "UNIX-CONNECT:$SERIAL_SOCK"
else
  {
    sleep 1
    printf '%s\n' "$command_text"
    sleep "${SERIAL_COMMAND_SETTLE_SECONDS:-2}"
  } | /run/current-system/sw/bin/nix --extra-experimental-features nix-command --extra-experimental-features flakes shell nixpkgs#socat -c \
    socat - "UNIX-CONNECT:$SERIAL_SOCK"
fi
