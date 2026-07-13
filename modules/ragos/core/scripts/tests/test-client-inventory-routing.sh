#!/usr/bin/env bash
# Purpose: Validar roteamento legado e nova semantica compativel do inventario
# Category: tests
# Safety: safe
# Expected environment: checkout do RAGOS com nix-instantiate disponivel
# Requires: nix

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  grep -Fq "$needle" <<<"$haystack" || {
    echo "ASSERT FAIL [$label]: missing '$needle'" >&2
    exit 1
  }
}

inventory_expr="$(cat <<EOF
let
  lib = import <nixpkgs/lib>;
  inventoryLib = import $repo_root/server/network/clients-inventory-lib.nix { inherit lib; };
  validated = inventoryLib.validateInventoryWithPolicy {
    requireNonEmpty = true;
    inventory = [
      {
        mac = "52:54:00:64:10:11";
        hostname = "tc-default";
        ip = "192.168.100.110";
      }
      {
        mac = "52:54:00:64:10:12";
        hostname = "tc-new";
        ip = "192.168.100.111";
        releaseTrack = "pilot";
        clientProfile = "hyperv-debug";
        hardwareClass = "hyperv";
        bootMethod = "uefi-http";
      }
      {
        mac = "52:54:00:64:10:13";
        hostname = "tc-rescue";
        ip = "192.168.100.112";
        channel = "rescue";
        releaseTrack = "rescue";
        profile = "rescue-minimal";
        clientProfile = "rescue";
        hardwareClass = "rescue";
        bootMethod = "ipxe";
      }
    ];
  };
in
builtins.toJSON {
  dhcpHosts = validated.dhcpHosts;
  ipxeRoutes = validated.ipxeRoutes;
  resolvedClients = validated.resolvedClients;
}
EOF
)"

validated_json="$(
  nix-instantiate --eval --strict --raw --expr "$inventory_expr" \
    | python3 -c 'import json,sys; print(json.dumps(json.loads(sys.stdin.read()), separators=(",", ":")))'
)"

echo "[1/4] inventario legado continua roteando para o contrato atual"
assert_contains "$validated_json" 'set:chan-generic,set:hw-physical-generic,tc-default,192.168.100.110,infinite' "default generic dhcp tags"
assert_contains "$validated_json" '"hostname":"tc-default"' "default hostname"
assert_contains "$validated_json" '"channel":"generic"' "default channel"
assert_contains "$validated_json" '"releaseTrack":"stable"' "default releaseTrack"
assert_contains "$validated_json" '"profile":"desktop-generic"' "default profile"
assert_contains "$validated_json" '"clientProfile":"workstation"' "default clientProfile"
assert_contains "$validated_json" '"hardwareClass":"physical-generic"' "default hardwareClass"
assert_contains "$validated_json" '"bootMethod":"ipxe"' "default bootMethod"
assert_contains "$validated_json" '"bootEndpoint":"generic.ipxe"' "default boot endpoint"

echo "[2/4] nova semantica normaliza para canal lab sem tocar o bundle atual"
assert_contains "$validated_json" 'set:chan-lab,set:hw-hyperv,tc-new,192.168.100.111,infinite' "new semantic dhcp tags"
assert_contains "$validated_json" '"hostname":"tc-new"' "new hostname"
assert_contains "$validated_json" '"channel":"lab"' "new channel"
assert_contains "$validated_json" '"releaseTrack":"pilot"' "new releaseTrack"
assert_contains "$validated_json" '"profile":"hyperv-debug"' "new profile"
assert_contains "$validated_json" '"clientProfile":"hyperv-debug"' "new clientProfile"
assert_contains "$validated_json" '"hardwareClass":"hyperv"' "new hardwareClass"
assert_contains "$validated_json" '"bootMethod":"uefi-http"' "new bootMethod"
assert_contains "$validated_json" '"bootEndpoint":"lab.ipxe"' "new boot endpoint"

echo "[3/4] inventario coerente com campos velhos e novos continua aceito"
assert_contains "$validated_json" 'set:chan-rescue,set:hw-rescue,tc-rescue,192.168.100.112,infinite' "rescue dhcp tags"
assert_contains "$validated_json" '"hostname":"tc-rescue"' "rescue hostname"
assert_contains "$validated_json" '"channel":"rescue"' "rescue channel"
assert_contains "$validated_json" '"releaseTrack":"rescue"' "rescue releaseTrack"
assert_contains "$validated_json" '"profile":"rescue-minimal"' "rescue profile"
assert_contains "$validated_json" '"clientProfile":"rescue"' "rescue clientProfile"
assert_contains "$validated_json" '"hardwareClass":"rescue"' "rescue hardwareClass"
assert_contains "$validated_json" '"bootMethod":"ipxe"' "rescue bootMethod"
assert_contains "$validated_json" '"bootEndpoint":"rescue.ipxe"' "rescue boot endpoint"

echo "[4/4] artefatos derivados continuam presos ao endpoint de canal atual"
assert_contains "$validated_json" '"bootEndpoint":"generic.ipxe"' "generic endpoint"
assert_contains "$validated_json" '"bootEndpoint":"lab.ipxe"' "lab endpoint"
assert_contains "$validated_json" '"bootEndpoint":"rescue.ipxe"' "rescue endpoint"

echo "Client inventory routing harness passed."
