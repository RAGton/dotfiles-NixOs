#!/usr/bin/env bash
# Purpose: Validar fail-closed de runtime nos outputs oficiais e no publish do ragc
# Category: tests
# Safety: safe
# Expected environment: dev shell com Nix flakes
# Requires: nix

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
nix_cmd=(nix --extra-experimental-features "nix-command flakes")

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  grep -Fq "$needle" <<<"$haystack" || {
    echo "ASSERT FAIL [$label]: missing '$needle'" >&2
    exit 1
  }
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  [[ "$expected" == "$actual" ]] || {
    echo "ASSERT FAIL [$label]: expected '$expected', got '$actual'" >&2
    exit 1
  }
}

tmp_runtime="$(mktemp -d)"
tmp_work="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_runtime" "$tmp_work"
}
trap cleanup EXIT

echo "[1/4] official client output fails closed sem runtime"
set +e
official_fail="$({ RAGOS_RUNTIME_ROOT="$tmp_runtime" "${nix_cmd[@]}" eval --impure "path:$repo_root#nixosConfigurations.ragos-client-desktop-generic.config.ragos.profile.name"; } 2>&1)"
official_rc=$?
set -e
[[ "$official_rc" -ne 0 ]] || {
  echo "ASSERT FAIL [official fail closed]: output oficial avaliou sem runtime" >&2
  exit 1
}
assert_contains "$official_fail" "outputs oficiais exigem runtime persistente real" "official fail message"

echo "[2/4] dev output continua avaliavel sem runtime"
dev_profile="$(RAGOS_RUNTIME_ROOT="$tmp_runtime" "${nix_cmd[@]}" eval --impure --raw "path:$repo_root#nixosConfigurations.ragos-client-dev-desktop-generic.config.ragos.profile.name")"
assert_eq "desktop-generic" "$dev_profile" "dev output profile"

echo "[3/4] official output volta a avaliar com runtime real presente"
cp "$repo_root/server/runtime/params.example.nix" "$tmp_runtime/params.nix"
cp "$repo_root/server/runtime/hardware-configuration.example.nix" "$tmp_runtime/hardware-configuration.nix"
sed -i 's/runtimeSource = "example";/runtimeSource = "runtime";/' "$tmp_runtime/params.nix"
official_profile="$(RAGOS_RUNTIME_ROOT="$tmp_runtime" "${nix_cmd[@]}" eval --impure --raw "path:$repo_root#nixosConfigurations.ragos-client-desktop-generic.config.ragos.profile.name")"
assert_eq "desktop-generic" "$official_profile" "official output profile"

echo "[4/4] ragc switch falha cedo quando runtime de publicacao nao existe"
system="$("${nix_cmd[@]}" eval --impure --raw --expr builtins.currentSystem)"
ragc_out="$("${nix_cmd[@]}" build --impure --no-link --print-out-paths "path:$repo_root#packages.$system.ragc")"
ragc_bin="$ragc_out/bin/ragc"

mkdir -p "$tmp_work/data/images" "$tmp_work/http" "$tmp_work/tftp"
set +e
switch_fail="$({
  RAGOS_RUNTIME_ROOT="$(mktemp -d)" \
  RAGOS_FLAKE="$repo_root" \
  RAGC_SERVER_IP="127.0.0.1" \
  RAGC_HTTP_PORT="18080" \
  RAGC_DATA_ROOT="$tmp_work/data" \
  RAGC_IMAGES_ROOT="$tmp_work/data/images" \
  RAGC_HTTP_ROOT="$tmp_work/http" \
  RAGC_TFTP_ROOT="$tmp_work/tftp" \
  RAGC_LOCK_PATH="$tmp_work/ragc.lock" \
  RAGC_LOCK_TIMEOUT=2 \
  RAGC_SKIP_STORAGE_CHECKS=1 \
  RAGC_SKIP_SERVICE_CHECKS=1 \
  RAGC_SKIP_HTTP_CHECKS=1 \
  "$ragc_bin" switch --channel generic;
} 2>&1)"
switch_rc=$?
set -e
[[ "$switch_rc" -ne 0 ]] || {
  echo "ASSERT FAIL [ragc runtime guard]: switch nao falhou sem runtime" >&2
  exit 1
}
assert_contains "$switch_fail" "Runtime ausente: publicacao oficial exige" "ragc runtime guard message"

echo "Runtime guardrails harness passed."