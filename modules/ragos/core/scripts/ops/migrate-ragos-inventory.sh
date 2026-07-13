#!/usr/bin/env bash
# Purpose: Bootstrap do inventario externo em /etc/ragos-inventory
# Category: ops
# Safety: safe
# Expected environment: srv-rag ou host administrativo com checkout do repositorio
# Requires: root
# Notes: Nao sobrescreve inventario existente

set -euo pipefail

inventory_dir="${1:-/etc/ragos-inventory}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
bootstrap_file="$repo_root/server/network/clients-inventory.bootstrap.nix"
readme_template="$repo_root/server/network/clients-inventory.README.md"
target_inventory="$inventory_dir/clients.nix"
target_readme="$inventory_dir/README.md"

if [[ $EUID -ne 0 ]]; then
  echo "Execute como root: sudo $0" >&2
  exit 1
fi

install -d -m 0755 "$inventory_dir"

if [[ ! -f "$target_inventory" ]]; then
  install -m 0644 "$bootstrap_file" "$target_inventory"
  echo "Inventario bootstrap copiado para $target_inventory"
else
  echo "Inventario externo ja existe em $target_inventory; nada foi sobrescrito."
fi

if [[ ! -f "$target_readme" ]]; then
  install -m 0644 "$readme_template" "$target_readme"
  echo "README operacional copiado para $target_readme"
else
  echo "README externo ja existe em $target_readme; nada foi sobrescrito."
fi

if [[ ! -d "$inventory_dir/.git" ]]; then
  cat <<EOF
Sugestao: inicialize versionamento proprio do inventario:
  cd $inventory_dir
  git init
  git add clients.nix README.md
  git commit -m "Bootstrap RAGOS inventory"
EOF
fi
