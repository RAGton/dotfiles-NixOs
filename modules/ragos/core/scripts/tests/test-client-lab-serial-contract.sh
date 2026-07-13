#!/usr/bin/env bash
# Purpose: Validar o contrato de acesso serial do cliente desktop-lab no libvirt
# Category: tests
# Safety: safe
# Expected environment: checkout do RAGOS com Nix flakes
# Requires: nix, python3

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
nix_cmd=(nix --extra-experimental-features "nix-command flakes")

tmp_runtime="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_runtime"
}
trap cleanup EXIT

cp "$repo_root/server/runtime/params.example.nix" "$tmp_runtime/params.nix"
cp "$repo_root/server/runtime/hardware-configuration.example.nix" "$tmp_runtime/hardware-configuration.nix"
sed -i 's/runtimeSource = "example";/runtimeSource = "runtime";/' "$tmp_runtime/params.nix"

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  grep -Fq "$needle" <<<"$haystack" || {
    echo "ASSERT FAIL [$label]: missing '$needle'" >&2
    exit 1
  }
}

client_expr="$(cat <<EOF
let
  flake = builtins.getFlake "path:$repo_root";
  cfg = flake.nixosConfigurations.ragos-client-desktop-lab.config;
  serviceEnabled = name:
    if builtins.hasAttr name cfg.systemd.services then
      ((builtins.getAttr name cfg.systemd.services).enable or false)
    else
      false;
in
builtins.toJSON {
  profileName = cfg.ragos.profile.name or "";
  kernelParams = cfg.boot.kernelParams or [ ];
  gettyTty1 = serviceEnabled "getty@tty1";
  serialGettyTtyS0 = serviceEnabled "serial-getty@ttyS0";
}
EOF
)"

echo "[1/3] avaliar desktop-lab com runtime temporario controlado"
client_json="$(
  RAGOS_RUNTIME_ROOT="$tmp_runtime" \
  RAGOS_ALLOW_PLACEHOLDER_RUNTIME=1 \
  RAGOS_ENFORCE_RUNTIME_GUARDS=0 \
  "${nix_cmd[@]}" eval --impure --raw --expr "$client_expr" \
    | python3 -c 'import json,sys; print(json.dumps(json.loads(sys.stdin.read()), separators=(",", ":")))'
)"

echo "[2/3] perfil lab preserva o console local"
assert_contains "$client_json" '"profileName":"desktop-lab"' "profile name"
assert_contains "$client_json" '"gettyTty1":true' "tty1 getty"
assert_contains "$client_json" '"console=tty1"' "tty1 kernel console"

echo "[3/3] perfil lab expoe fallback serial barato para prova via libvirt"
assert_contains "$client_json" '"serialGettyTtyS0":true' "ttyS0 serial getty"
assert_contains "$client_json" '"console=ttyS0,115200n8"' "ttyS0 kernel console"

echo "Client lab serial contract harness passed."
