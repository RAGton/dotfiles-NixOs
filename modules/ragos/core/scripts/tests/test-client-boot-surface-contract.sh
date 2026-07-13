#!/usr/bin/env bash
# Purpose: Validar o contrato de superficies de boot dos perfis oficiais do cliente
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

expr_json="$(cat <<EOF
let
  flake = builtins.getFlake "path:$repo_root";
  generic = flake.nixosConfigurations.ragos-client-desktop-generic.config;
  lab = flake.nixosConfigurations.ragos-client-desktop-lab.config;
  profileSummary = cfg: {
    profileName = cfg.ragos.profile.name or "";
    bootVerbose = cfg.ragos.profile.bootVerbose or false;
    plymouth = cfg.boot.plymouth.enable or false;
    kernelParams = cfg.boot.kernelParams or [ ];
  };
in
builtins.toJSON {
  generic = profileSummary generic;
  lab = profileSummary lab;
}
EOF
)"

echo "[1/3] avaliar perfis generic e lab com runtime temporario controlado"
profiles_json="$(
  RAGOS_RUNTIME_ROOT="$tmp_runtime" \
  RAGOS_ALLOW_PLACEHOLDER_RUNTIME=1 \
  RAGOS_ENFORCE_RUNTIME_GUARDS=0 \
  "${nix_cmd[@]}" eval --impure --raw --expr "$expr_json" \
    | python3 -c 'import json,sys; print(json.dumps(json.loads(sys.stdin.read()), separators=(",", ":")))'
)"

echo "[2/3] desktop-generic preserva boot silencioso com Plymouth"
assert_contains "$profiles_json" '"profileName":"desktop-generic"' "generic profile name"
assert_contains "$profiles_json" '"bootVerbose":false' "generic bootVerbose false"
assert_contains "$profiles_json" '"plymouth":true' "generic plymouth enabled"
assert_contains "$profiles_json" '"quiet"' "generic quiet kernel param"
assert_contains "$profiles_json" '"splash"' "generic splash kernel param"

echo "[3/3] desktop-lab e verbose por contrato e nao promete Plymouth"
assert_contains "$profiles_json" '"profileName":"desktop-lab"' "lab profile name"
assert_contains "$profiles_json" '"bootVerbose":true' "lab bootVerbose true"
assert_contains "$profiles_json" '"plymouth":false' "lab plymouth disabled"
assert_contains "$profiles_json" '"loglevel=6"' "lab verbose loglevel"
assert_contains "$profiles_json" '"systemd.show_status=yes"' "lab systemd status"

echo "Client boot surface contract harness passed."
