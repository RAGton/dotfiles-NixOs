#!/usr/bin/env bash
# Purpose: Exercitar o fluxo principal de switch e doctor do ragc
# Category: tests
# Safety: safe
# Expected environment: dev shell com Nix flakes e portas locais livres
# Requires: nix
# Notes: Usa diretorios temporarios e um servidor HTTP local

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
nix_cmd=(nix --extra-experimental-features "nix-command flakes")
system="$("${nix_cmd[@]}" eval --impure --raw --expr builtins.currentSystem)"
ragc_out="$("${nix_cmd[@]}" build --no-link --print-out-paths "path:$repo_root#packages.$system.ragc")"
ragc_bin="$ragc_out/bin/ragc"

workdir="$(mktemp -d)"
http_pid=""

cleanup() {
  if [[ -n "$http_pid" ]]; then
    kill "$http_pid" 2>/dev/null || true
    wait "$http_pid" 2>/dev/null || true
  fi
  rm -rf "$workdir"
}
trap cleanup EXIT

export RAGC_SERVER_IP="127.0.0.1"
export RAGC_HTTP_PORT="18080"
export RAGC_DATA_ROOT="$workdir/data"
export RAGC_HTTP_ROOT="$workdir/http"
export RAGC_IMAGES_ROOT="$workdir/data/images"
export RAGC_TFTP_ROOT="$workdir/tftp"
export RAGC_LOCK_PATH="$workdir/ragc.lock"
export RAGC_LOCK_TIMEOUT=2
export RAGC_SKIP_STORAGE_CHECKS=1
export RAGC_SKIP_SERVICE_CHECKS=1
export RAGC_SKIP_HTTP_CHECKS=1
export RAGC_ALLOW_NON_NIX_STORE_PATHS=1

mkdir -p \
  "$RAGC_DATA_ROOT/home" \
  "$RAGC_DATA_ROOT/images" \
  "$RAGC_DATA_ROOT/snapshots" \
  "$RAGC_HTTP_ROOT" \
  "$RAGC_TFTP_ROOT/EFI/BOOT"
touch "$RAGC_TFTP_ROOT/EFI/BOOT/BOOTX64.EFI"
ln -s "$RAGC_IMAGES_ROOT" "$RAGC_HTTP_ROOT/netboot"

nix --extra-experimental-features "nix-command flakes" shell nixpkgs#python3 \
  -c python3 -m http.server "$RAGC_HTTP_PORT" --directory "$RAGC_HTTP_ROOT" >/dev/null 2>&1 &
http_pid="$!"
sleep 1

make_fake_system() {
  local name="$1"
  local dir="$workdir/builds/$name"

  mkdir -p "$dir"
  printf 'kernel-%s\n' "$name" > "$dir/kernel"
  printf 'initrd-%s\n' "$name" > "$dir/initrd"
  printf 'init-%s\n' "$name" > "$dir/init"
  printf 'loglevel=4\n' > "$dir/kernel-params"
  printf '%s\n' "$dir"
}

current_version() {
  basename "$(readlink -f "$RAGC_IMAGES_ROOT/current")"
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

assert_ne() {
  local left="$1"
  local right="$2"
  local label="$3"
  [[ "$left" != "$right" ]] || {
    echo "ASSERT FAIL [$label]: values should differ ('$left')" >&2
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

echo "[1/6] initial switch"
export RAGC_TEST_SYSTEM_PATH
RAGC_TEST_SYSTEM_PATH="$(make_fake_system gen-a)"
"$ragc_bin" switch >/dev/null
version_a="$(current_version)"

echo "[2/6] interruption between stage and promote"
RAGC_TEST_SYSTEM_PATH="$(make_fake_system gen-b)"
export RAGC_TEST_PAUSE_AT="after-stage"
export RAGC_TEST_PAUSE_FILE="$workdir/after-stage.pause"
"$ragc_bin" switch >/dev/null 2>&1 &
pause_pid="$!"
while [[ ! -f "$RAGC_TEST_PAUSE_FILE" ]]; do sleep 0.1; done
assert_eq "$version_a" "$(current_version)" "current preserved while staged"
kill "$pause_pid"
wait "$pause_pid" || true
unset RAGC_TEST_PAUSE_AT RAGC_TEST_PAUSE_FILE
"$ragc_bin" switch >/dev/null
version_b="$(current_version)"
assert_ne "$version_a" "$version_b" "switch after interruption converges"

echo "[3/6] lock contention"
RAGC_TEST_SYSTEM_PATH="$(make_fake_system gen-c)"
export RAGC_TEST_PAUSE_AT="after-lock"
export RAGC_TEST_PAUSE_FILE="$workdir/after-lock.pause"
"$ragc_bin" switch >/dev/null 2>&1 &
lock_pid="$!"
while [[ ! -f "$RAGC_TEST_PAUSE_FILE" ]]; do sleep 0.1; done
set +e
lock_output="$("$ragc_bin" switch 2>&1)"
lock_rc=$?
set -e
[[ "$lock_rc" -ne 0 ]] || {
  echo "ASSERT FAIL [lock contention]: second switch unexpectedly succeeded" >&2
  exit 1
}
assert_contains "$lock_output" "lock global" "lock contention message"
touch "${RAGC_TEST_PAUSE_FILE}.continue"
wait "$lock_pid"
unset RAGC_TEST_PAUSE_AT RAGC_TEST_PAUSE_FILE
version_c="$(current_version)"
assert_ne "$version_b" "$version_c" "first switch completed after contention"

echo "[4/6] doctor determinism and boot coherence"
doctor_out_1="$("$ragc_bin" doctor 2>&1)"
doctor_rc_1=$?
doctor_out_2="$("$ragc_bin" doctor 2>&1)"
doctor_rc_2=$?
assert_eq "$doctor_rc_1" "$doctor_rc_2" "doctor exit code is stable"
assert_eq "$doctor_out_1" "$doctor_out_2" "doctor output is stable"
boot_declared="$(awk '$1 == "set" && $2 == "current_build_id" { print $3; exit }' "$RAGC_HTTP_ROOT/boot.ipxe")"
current_declared="$(awk '$1 == "set" && $2 == "build_id" { print $3; exit }' "$RAGC_HTTP_ROOT/current.ipxe")"
http_declared="$(curl -fsS "http://127.0.0.1:$RAGC_HTTP_PORT/netboot/current/manifest.json" | grep -E '"id"[[:space:]]*:' | head -n1 | cut -d'"' -f4)"
assert_eq "$version_c" "$boot_declared" "boot.ipxe coherence"
assert_eq "$version_c" "$current_declared" "current.ipxe coherence"
assert_eq "$version_c" "$http_declared" "http manifest coherence"

echo "[5/6] rollback idempotence"
"$ragc_bin" rollback >/dev/null
rolled_back_version="$(current_version)"
"$ragc_bin" rollback >/dev/null
assert_eq "$rolled_back_version" "$(current_version)" "rollback rerun stays on same target"

echo "[6/6] fail closed without Tier 1"
mount_test_root="$(mktemp -d)"
set +e
mount_fail="$(
  RAGC_SKIP_STORAGE_CHECKS=0 \
  RAGC_DATA_ROOT="$mount_test_root/data" \
  RAGC_IMAGES_ROOT="$mount_test_root/data/images" \
  RAGC_HTTP_ROOT="$mount_test_root/http" \
  RAGC_TFTP_ROOT="$mount_test_root/tftp" \
  RAGC_TEST_SYSTEM_PATH="$(make_fake_system gen-d)" \
  "$ragc_bin" switch 2>&1
)"
mount_rc=$?
set -e
rm -rf "$mount_test_root"
[[ "$mount_rc" -ne 0 ]] || {
  echo "ASSERT FAIL [fail closed mount]: switch unexpectedly succeeded without Tier 1" >&2
  exit 1
}
assert_contains "$mount_fail" "Tier 1 indisponivel" "fail closed mount message"

echo "Phase A ragc harness passed."
