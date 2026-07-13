#!/usr/bin/env bash
# Purpose: Validar contrato installer -> first publish channel-first
# Category: tests
# Safety: safe
# Expected environment: checkout do RAGOS com nix-instantiate disponivel
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

assert_json_eq() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  [[ "$expected" == "$actual" ]] || {
    echo "ASSERT FAIL [$label]: expected JSON $expected, got $actual" >&2
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

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq "$needle" <<<"$haystack"; then
    echo "ASSERT FAIL [$label]: unexpected '$needle'" >&2
    exit 1
  fi
}

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

params_file="$tmp_dir/params.nix"

# shellcheck source=/dev/null
source "$repo_root/installer/lib/params.sh"

echo "[1/4] gerar params.nix com defaults de publicacao"
generate_params_nix \
  "$params_file" \
  "192.168.100.10" "8080" \
  "srv-rag" "UTC" "en_US.UTF-8" "us" \
  "enp1s0" "24" "192.168.100.1" "1.1.1.1,8.8.8.8" \
  "enp2s0" "dhcp" "" "" "" "" "" \
  "admin" "1000" "admin@example.test" '$y$j9T$fakehash' \
  "" \
  "/dev/sdb" "btrfs" \
  "0" "active-backup" "enp1s0,enp3s0"

params_content="$(cat "$params_file")"
assert_contains "$params_content" 'clientDefaultChannel = "generic";' "params default channel"
assert_contains "$params_content" 'runtimeSource = "runtime";' "params runtime source"
assert_contains "$params_content" 'inventoryDir = "/etc/ragos-inventory";' "params inventory dir"
assert_contains "$params_content" 'inventoryRequireNonEmpty = false;' "params inventory policy"

echo "[2/4] validar campos essenciais via avaliacao nix"
client_channel="$(nix-instantiate --eval --strict --expr "(import $params_file).clientDefaultChannel" | tr -d '"')"
runtime_source="$(nix-instantiate --eval --strict --expr "(import $params_file).runtimeSource" | tr -d '"')"
require_non_empty="$(nix-instantiate --eval --strict --expr "(import $params_file).inventoryRequireNonEmpty")"
assert_eq "generic" "$client_channel" "clientDefaultChannel"
assert_eq "runtime" "$runtime_source" "runtimeSource"
assert_eq "false" "$require_non_empty" "inventoryRequireNonEmpty"

echo "[3/4] validar que politica do inventario permite seed vazio no primeiro boot"
policy_expr="$(cat <<EOF
let
  lib = import <nixpkgs/lib>;
  params = import $params_file;
  inventoryLib = import $repo_root/server/network/clients-inventory-lib.nix { inherit lib; };
  validated = inventoryLib.validateInventoryWithPolicy {
    inventory = [ ];
    requireNonEmpty = params.inventoryRequireNonEmpty;
  };
in
builtins.toJSON (
  builtins.map
    (assertion: assertion.message)
    (builtins.filter (assertion: !assertion.assertion) validated.assertions)
)
EOF
)"
policy_result="$(
  nix-instantiate --eval --strict --raw --expr "$policy_expr" \
    | python3 -c 'import json,sys; print(json.dumps(json.loads(sys.stdin.read()), separators=(",", ":")))'
)"
assert_json_eq "[]" "$policy_result" "empty inventory allowed at bootstrap"

echo "[4/4] validar documentacao de first publish channel-first"
installer_readme="$(cat "$repo_root/installer/README.md")"
assert_contains "$installer_readme" 'ragc switch --channel generic' "installer readme channel-first"
assert_not_contains "$installer_readme" 'ragc switch --target desktop-generic' "installer readme no target-first"

echo "Installer first-publish contract harness passed."
