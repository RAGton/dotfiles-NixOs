#!/bin/bash
# Purpose: Exercitar o comando doctor em um ambiente temporario estilo WSL
# Category: tests
# Safety: safe
# Expected environment: dev shell ou WSL com Bash e Nix
# Requires: nix

set -euo pipefail

export IMAGES_ROOT="/tmp/ragos-test-doctor/srv/data/images"
export HTTP_ROOT="/tmp/ragos-test-doctor/srv/http"
export SERVER_IP="127.0.0.1"
export HTTP_PORT="8080"
export RAGC_GC_GRACE_SECONDS="1"

REPO_ROOT="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd)"
TEST_ROOT="${IMAGES_ROOT%/srv/data/images}"
rm -rf "$TEST_ROOT"
mkdir -p "$IMAGES_ROOT" "$HTTP_ROOT"
ln -sfn "$IMAGES_ROOT" "$HTTP_ROOT/netboot"
echo "v-test" > "$HTTP_ROOT/boot.ipxe"

source "$REPO_ROOT/ragc/lib/common.sh"

check_service() { print_check "$1" "OK"; (( DOCTOR_OK++ )) || true; }
check_http() { print_check "$2" "OK"; (( DOCTOR_OK++ )) || true; }
check_dir() {
  local path="$1"
  local label="$2"
  if [[ "$path" == "/srv/data" || "$path" == "/srv/data/home" || "$path" == "/srv/tftp"* ]]; then
    print_check "$label" "OK"
    (( DOCTOR_OK++ )) || true
    return
  fi
  if [[ -d "$path" ]]; then
    print_check "$label" "OK"
    (( DOCTOR_OK++ )) || true
  else
    print_check "$label" "FAIL"
    (( DOCTOR_FAIL++ )) || true
  fi
}
check_file() {
  local path="$1"
  local label="$2"
  if [[ "$path" == "/srv/tftp/"* ]]; then
    print_check "$label" "OK"
    (( DOCTOR_OK++ )) || true
    return
  fi
  if [[ -f "$path" ]]; then
    print_check "$label" "OK"
    (( DOCTOR_OK++ )) || true
  else
    print_check "$label" "FAIL"
    (( DOCTOR_FAIL++ )) || true
  fi
}

source "$REPO_ROOT/ragc/commands/doctor.sh"

mkdir -p "$IMAGES_ROOT/v-orphan"
touch -d "@$(( $(date +%s) - 10 ))" "$IMAGES_ROOT/v-orphan" 2>/dev/null || true
ln -sfn "$IMAGES_ROOT/does-not-exist" "$IMAGES_ROOT/current"

cmd_doctor >/dev/null

[[ "${DOCTOR_FAIL:-0}" -ge 2 ]] || die "doctor deveria acusar estado inseguro (falhas=${DOCTOR_FAIL:-0})"

log_ok "WSL doctor Phase 2 checks completed successfully."
