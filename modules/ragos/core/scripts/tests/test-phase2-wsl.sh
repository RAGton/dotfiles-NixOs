#!/bin/bash
# Purpose: Validar GC e snapshots do ragc em um ambiente temporario estilo WSL
# Category: tests
# Safety: safe
# Expected environment: dev shell ou WSL com Bash e Nix
# Requires: nix

set -euo pipefail

export IMAGES_ROOT="/tmp/ragos-test-phase2/srv/data/images"
export HTTP_ROOT="/tmp/ragos-test-phase2/srv/http"
export SERVER_IP="127.0.0.1"
export HTTP_PORT="8080"
export KEEP_VERSIONS="2"
export RAGC_SNAPSHOTS_ROOT="/tmp/ragos-test-phase2/srv/data/snapshots"
export RAGC_GC_GRACE_SECONDS="60"
export RAGC_GC_SNAPSHOT_KEEP="2"

REPO_ROOT="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd)"
TEST_ROOT="${IMAGES_ROOT%/srv/data/images}"
rm -rf "$TEST_ROOT"
mkdir -p "$IMAGES_ROOT" "$HTTP_ROOT" "$RAGC_SNAPSHOTS_ROOT"
ln -sfn "$IMAGES_ROOT" "$HTTP_ROOT/netboot"

source "$REPO_ROOT/ragc/lib/common.sh"
source "$REPO_ROOT/ragc/commands/gc.sh"

mkgen() {
  local id="$1"
  local age="$2"
  local with_manifest="$3"

  local dir="$IMAGES_ROOT/$id"
  mkdir -p "$dir"
  touch "$dir/bzImage" "$dir/initrd"
  if [[ "$with_manifest" == "yes" ]]; then
    echo '{"id":"'"$id"'","status":"active"}' > "$dir/manifest.json"
  fi
  touch -d "@$(( $(date +%s) - age ))" "$dir" 2>/dev/null || true
}

log_section "==> Phase 2 WSL Simulation"

mkgen "v-old1" 7200 yes
mkgen "v-old2" 7100 yes
mkgen "v-old3" 7000 yes

ln -sfn "$IMAGES_ROOT/v-old3" "$IMAGES_ROOT/current"
ln -sfn "$IMAGES_ROOT/v-old2" "$IMAGES_ROOT/previous"

log_info "Before GC:"
ls -1 "$IMAGES_ROOT" | sort

cmd_gc 2

log_info "After GC:"
ls -1 "$IMAGES_ROOT" | sort

[[ ! -d "$IMAGES_ROOT/v-old1" ]] || die "GC não removeu v-old1"
[[ -d "$IMAGES_ROOT/v-old2" ]] || die "GC removeu v-old2 (previous)"
[[ -d "$IMAGES_ROOT/v-old3" ]] || die "GC removeu v-old3 (current)"

snap1="$(ls -1t "$RAGC_SNAPSHOTS_ROOT" 2>/dev/null | grep '^images-pre-gc-' | head -n 1 || true)"
[[ -n "$snap1" ]] || die "Snapshot pré-GC não foi criado"
[[ -d "$RAGC_SNAPSHOTS_ROOT/$snap1/v-old1" ]] || die "Snapshot não contém a geração removida"

mkgen "v-recent" 10 yes
mkgen "v-old4" 7300 yes
mkgen "v-unknown-old" 7300 no

cmd_gc 2

[[ ! -d "$IMAGES_ROOT/v-old4" ]] || die "GC não removeu v-old4"
[[ -d "$IMAGES_ROOT/v-recent" ]] || die "GC removeu v-recent (janela recente)"
[[ -d "$IMAGES_ROOT/v-unknown-old" ]] || die "GC removeu diretório sem manifest"

mkgen "v-old5" 7400 yes
cmd_gc 2

snap_count="$(ls -1 "$RAGC_SNAPSHOTS_ROOT" | grep -c '^images-pre-gc-' || true)"
[[ "$snap_count" -le 2 ]] || die "Retenção de snapshots não aplicada (esperado <=2, atual=$snap_count)"

set +e
ln -sfn "$IMAGES_ROOT/does-not-exist" "$IMAGES_ROOT/current"
cmd_gc 2 >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -ne 0 ]] || die "GC deveria falhar com ponteiro current quebrado"

log_ok "WSL Phase 2 Simulation tests completed successfully."
