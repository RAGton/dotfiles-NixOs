#!/usr/bin/env bash
# Purpose: Validar publicacao por canal e rollback por canal no ragc
# Category: tests
# Safety: safe
# Expected environment: dev shell com Nix flakes
# Requires: nix

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
nix_cmd=(nix --extra-experimental-features "nix-command flakes")
system="$("${nix_cmd[@]}" eval --impure --raw --expr builtins.currentSystem)"
ragc_out="$("${nix_cmd[@]}" build --impure --no-link --print-out-paths "path:$repo_root#packages.$system.ragc")"
ragc_bin="$ragc_out/bin/ragc"

workdir="$(mktemp -d)"
cleanup() {
  rm -rf "$workdir"
}
trap cleanup EXIT

export RAGC_SERVER_IP="127.0.0.1"
export RAGC_HTTP_PORT="18081"
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

mkdir -p "$RAGC_DATA_ROOT/images" "$RAGC_DATA_ROOT/home" "$RAGC_DATA_ROOT/snapshots" "$RAGC_HTTP_ROOT" "$RAGC_TFTP_ROOT/EFI/BOOT"
ln -s "$RAGC_IMAGES_ROOT" "$RAGC_HTTP_ROOT/netboot"
touch "$RAGC_TFTP_ROOT/EFI/BOOT/BOOTX64.EFI"

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

pointer_version() {
  local name="$1"
  basename "$(readlink -f "$RAGC_IMAGES_ROOT/$name")"
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

manifest_field() {
  local version="$1"
  local field="$2"
  grep -E "\"$field\"[[:space:]]*:" "$RAGC_IMAGES_ROOT/$version/manifest.json" | head -n1 | cut -d'"' -f4
}

ipxe_declared_value() {
  local script_path="$1"
  local variable="$2"
  awk -v var="$variable" '$1 == "set" && $2 == var { print $3; exit }' "$script_path" 2>/dev/null
}

echo "[1/6] publicar canal generic"
export RAGC_TEST_SYSTEM_PATH
RAGC_TEST_SYSTEM_PATH="$(make_fake_system generic-a)"
"$ragc_bin" switch --channel generic >/dev/null
generic_a="$(pointer_version current-generic)"
assert_eq "$generic_a" "$(pointer_version current)" "global current tracks generic"

echo "[2/6] publicar canal lab duas vezes"
RAGC_TEST_SYSTEM_PATH="$(make_fake_system lab-a)"
"$ragc_bin" switch --channel lab >/dev/null
lab_a="$(pointer_version current-lab)"
RAGC_TEST_SYSTEM_PATH="$(make_fake_system lab-b)"
"$ragc_bin" switch --channel lab >/dev/null
lab_b="$(pointer_version current-lab)"
assert_eq "$lab_a" "$(pointer_version previous-lab)" "previous-lab after second publish"
assert_eq "$generic_a" "$(pointer_version current-generic)" "generic pointer isolated from lab switch"

echo "[3/6] publicar canal rescue duas vezes"
RAGC_TEST_SYSTEM_PATH="$(make_fake_system rescue-a)"
"$ragc_bin" switch --channel rescue >/dev/null
rescue_a="$(pointer_version current-rescue)"
RAGC_TEST_SYSTEM_PATH="$(make_fake_system rescue-b)"
"$ragc_bin" switch --channel rescue >/dev/null
rescue_b="$(pointer_version current-rescue)"
assert_eq "$rescue_b" "$(pointer_version rescue)" "rescue pointer tracks current-rescue"
assert_eq "$rescue_a" "$(pointer_version previous-rescue)" "previous-rescue after second publish"

echo "[4/6] rollback do canal rescue nao altera generic/lab"
"$ragc_bin" rollback --channel rescue >/dev/null
assert_eq "$rescue_a" "$(pointer_version current-rescue)" "rescue rollback target"
assert_eq "$generic_a" "$(pointer_version current-generic)" "generic intact after rescue rollback"
assert_eq "$lab_b" "$(pointer_version current-lab)" "lab intact after rescue rollback"

echo "[5/6] rollback do canal lab nao altera generic/rescue"
"$ragc_bin" rollback --channel lab >/dev/null
assert_eq "$lab_a" "$(pointer_version current-lab)" "lab rollback target"
assert_eq "$lab_b" "$(pointer_version previous-lab)" "lab rollback source tracked"
assert_eq "$generic_a" "$(pointer_version current-generic)" "generic intact after lab rollback"
assert_eq "$rescue_a" "$(pointer_version current-rescue)" "rescue intact after lab rollback"

echo "[6/6] validar metadados channel/hardwareClass nos manifests"
assert_eq "generic" "$(manifest_field "$generic_a" channel)" "generic manifest channel"
assert_eq "physical-generic" "$(manifest_field "$generic_a" hardwareClass)" "generic manifest hardware"
assert_eq "lab" "$(manifest_field "$lab_a" channel)" "lab manifest channel"
assert_eq "physical-lab" "$(manifest_field "$lab_a" hardwareClass)" "lab manifest hardware"
assert_eq "rescue" "$(manifest_field "$rescue_a" channel)" "rescue manifest channel"
assert_eq "rescue" "$(manifest_field "$rescue_a" hardwareClass)" "rescue manifest hardware"
assert_eq "$generic_a" "$(ipxe_declared_value "$RAGC_HTTP_ROOT/generic.ipxe" build_id)" "generic ipxe pointer"
assert_eq "$lab_a" "$(ipxe_declared_value "$RAGC_HTTP_ROOT/lab.ipxe" build_id)" "lab ipxe pointer"
assert_eq "$rescue_a" "$(ipxe_declared_value "$RAGC_HTTP_ROOT/rescue.ipxe" build_id)" "rescue ipxe pointer"
grep -Fq 'chain --replace http://127.0.0.1:18081/by-mac/${net0/mac}.ipxe || goto menu' "$RAGC_HTTP_ROOT/boot.ipxe" || {
  echo "ASSERT FAIL [boot by-mac routing]: boot.ipxe nao consulta o roteamento por MAC" >&2
  exit 1
}

echo "RAGC channels harness passed."
