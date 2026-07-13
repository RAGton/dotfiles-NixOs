#!/usr/bin/env bash
# Purpose: Subir a UI do instalador a partir de um checkout local de laboratorio
# Category: lab
# Safety: lab-only
# Expected environment: WSL ou Linux local com checkout do installer-ui
# Requires: nix, cargo, rustc
# Notes: Resolve o checkout a partir do proprio repositorio, com override opcional

set -euo pipefail

repo_root="${RAGOS_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
installer_ui_dir="${RAGOS_INSTALLER_UI_DIR:-$repo_root/installer/installer-ui}"

if [[ ! -d "$installer_ui_dir" ]]; then
  printf 'Diretorio installer-ui nao encontrado: %s\n' "$installer_ui_dir" >&2
  exit 1
fi

cd "$installer_ui_dir"
export RAGOS_INSTALLER_LISTEN=0.0.0.0:8000
exec nix --extra-experimental-features "nix-command flakes" shell nixpkgs#cargo nixpkgs#rustc nixpkgs#gcc nixpkgs#pkg-config nixpkgs#openssl -c cargo run
