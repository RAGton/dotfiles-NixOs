#!/usr/bin/env bash
# Purpose: Validar contrato multi-NIC entre initrd, stage2 e artefatos iPXE
# Category: tests
# Safety: safe
# Expected environment: dev shell com Nix flakes
# Requires: nix

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
nix_cmd=(nix --extra-experimental-features "nix-command flakes")
client_cfg="path:$repo_root#nixosConfigurations.ragos-client-dev-desktop-generic.config"

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  grep -Fq "$needle" <<<"$haystack" || {
    echo "ASSERT FAIL [$label]: missing '$needle'" >&2
    exit 1
  }
}

echo "[1/4] validar initrd grava dicas de NIC primario"
post_network="$("${nix_cmd[@]}" eval --raw "$client_cfg.boot.initrd.network.postCommands")"
assert_contains "$post_network" "/run/ragos/boot-network.env" "initrd writes boot env"
assert_contains "$post_network" "BOOT_MAC=" "initrd exports boot mac"
assert_contains "$post_network" "selected_boot_mac" "initrd selected boot mac log"

echo "[2/4] validar prestart do networkd consome cmdline e hint do initrd"
network_module="$(cat "$repo_root/client/modules/boot/network-stage2.nix")"
assert_contains "$network_module" "ragos.primaryNicMac=" "networkd reads kernel cmdline"
assert_contains "$network_module" "/run/ragos/boot-network.env" "networkd reads initrd hint"
assert_contains "$network_module" "PermanentMACAddress=" "networkd pins preferred MAC"
assert_contains "$network_module" "RouteMetric=50" "preferred route metric"

echo "[3/4] validar fallback wired DHCP tem menor prioridade"
assert_contains "$network_module" "90-ragos-fallback-dhcp.network" "fallback network file"
assert_contains "$network_module" "RouteMetric=200" "wired fallback metric"

echo "[4/4] validar geracao iPXE propaga MAC primario"
boot_lib="$(cat "$repo_root/ragc/lib/boot.sh")"
assert_contains "$boot_lib" 'ragos.primaryNicMac=\${net0/mac}' "boot script carries MAC on cmdline"

echo "Multi-NIC contract harness passed."
