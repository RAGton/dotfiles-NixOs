#!/usr/bin/env bash
# Purpose: Construir a ISO do instalador a partir de um checkout em WSL
# Category: lab
# Safety: lab-only
# Expected environment: WSL com checkout local e acesso ao host Windows
# Requires: nix
# Notes: Usa caminhos pessoais do laboratorio

set -euo pipefail

repo_root="/mnt/c/Users/aguia/OneDrive/Documents/GitHub/ragos"
log_file="/mnt/c/Users/aguia/Documents/ragos-iso-build.log"
status_file="/mnt/c/Users/aguia/Documents/ragos-iso-build.status"
out_link="$repo_root/result-iso"

mkdir -p "$(dirname "$log_file")"
rm -f "$status_file"

cd "$repo_root"
rm -f "$out_link"

{
  echo "== RAGOS ISO BUILD =="
  date -Iseconds
  /run/current-system/sw/bin/nix \
    --extra-experimental-features nix-command \
    --extra-experimental-features flakes \
    build "path:$repo_root#ragos-iso" -L \
    --out-link "$out_link"
} >"$log_file" 2>&1

echo "OK $(date -Iseconds)" >"$status_file"
