#!/usr/bin/env bash
# Purpose: Validar regras de unicidade, compatibilidade e coerencia do inventario externo
# Category: tests
# Safety: safe
# Expected environment: dev shell com nix-instantiate e nixpkgs disponiveis
# Requires: nix

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

assert_eq() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  [[ "$expected" == "$actual" ]] || {
    echo "ASSERT FAIL [$label]: expected '$expected', got '$actual'" >&2
    exit 1
  }
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  grep -Fq "$needle" <<<"$haystack" || {
    echo "ASSERT FAIL [$label]: missing '$needle'" >&2
    exit 1
  }
}

eval_failures() {
  local payload="$1"
  local require_non_empty="${2:-true}"
  local expr
  expr="$(cat <<EOF
let
  lib = import <nixpkgs/lib>;
  inventoryLib = import $repo_root/server/network/clients-inventory-lib.nix { inherit lib; };
  validated = inventoryLib.validateInventoryWithPolicy {
    inventory = $payload;
    requireNonEmpty = $require_non_empty;
  };
in
builtins.toJSON (
  builtins.map
    (assertion: assertion.message)
    (builtins.filter (assertion: !assertion.assertion) validated.assertions)
)
EOF
)"

  nix-instantiate --eval --strict --raw --expr "$expr" \
    | python3 -c 'import json,sys; print(json.dumps(json.loads(sys.stdin.read()), separators=(",", ":")))'
}

echo "[1/7] detectar duplicidade basica"
duplicate_mac_failures="$(eval_failures '[
  { mac = "aa:aa:aa:aa:aa:aa"; hostname = "tc-a"; ip = "192.168.100.100"; }
  { mac = "aa:aa:aa:aa:aa:aa"; hostname = "tc-b"; ip = "192.168.100.101"; }
]')"
assert_contains "$duplicate_mac_failures" "MAC duplicado" "duplicate mac message"

duplicate_hostname_failures="$(eval_failures '[
  { mac = "aa:aa:aa:aa:aa:aa"; hostname = "tc-a"; ip = "192.168.100.100"; }
  { mac = "bb:bb:bb:bb:bb:bb"; hostname = "tc-a"; ip = "192.168.100.101"; }
]')"
assert_contains "$duplicate_hostname_failures" "hostname duplicado" "duplicate hostname message"

duplicate_ip_failures="$(eval_failures '[
  { mac = "aa:aa:aa:aa:aa:aa"; hostname = "tc-a"; ip = "192.168.100.100"; }
  { mac = "bb:bb:bb:bb:bb:bb"; hostname = "tc-b"; ip = "192.168.100.100"; }
]')"
assert_contains "$duplicate_ip_failures" "IP duplicado" "duplicate ip message"

echo "[2/7] inventario vazio continua fail-closed por padrao"
empty_forbidden="$(eval_failures '[ ]' 'true')"
assert_contains "$empty_forbidden" "inventario externo vazio" "empty inventory forbidden"

echo "[3/7] bootstrap vazio permitido continua funcionando quando explicitado"
empty_allowed="$(eval_failures '[ ]' 'false')"
assert_eq "[]" "$empty_allowed" "empty inventory allowed"

echo "[4/7] channel/releaseTrack incoerentes falham de forma explicita"
channel_track_mismatch="$(eval_failures '[
  {
    mac = "52:54:00:64:10:11";
    hostname = "tc-track";
    ip = "192.168.100.110";
    channel = "generic";
    releaseTrack = "pilot";
  }
]')"
assert_contains "$channel_track_mismatch" "channel e releaseTrack incoerentes" "channel releaseTrack mismatch"

echo "[5/7] profile/clientProfile incoerentes falham de forma explicita"
profile_alias_mismatch="$(eval_failures '[
  {
    mac = "52:54:00:64:10:12";
    hostname = "tc-profile";
    ip = "192.168.100.111";
    profile = "desktop-generic";
    clientProfile = "lab-workstation";
  }
]')"
assert_contains "$profile_alias_mismatch" "profile e clientProfile incoerentes" "profile clientProfile mismatch"

echo "[6/7] combinacoes impossiveis entre canal, profile e hardwareClass falham"
combo_mismatch="$(eval_failures '[
  {
    mac = "52:54:00:64:10:13";
    hostname = "tc-combo";
    ip = "192.168.100.112";
    releaseTrack = "stable";
    clientProfile = "lab-workstation";
    hardwareClass = "physical-lab";
  }
]')"
assert_contains "$combo_mismatch" "combinacao invalida" "semantic combo mismatch"

echo "[7/7] uefi-https continua reservado/futuro sem prova real"
https_reserved="$(eval_failures '[
  {
    mac = "52:54:00:64:10:14";
    hostname = "tc-https";
    ip = "192.168.100.113";
    bootMethod = "uefi-https";
  }
]')"
assert_contains "$https_reserved" "bootMethod=uefi-https ainda e reservado/futuro" "uefi-https reserved"

echo "Inventory validation harness passed."
