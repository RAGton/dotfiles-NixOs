cmd_gc_impl() {
  local keep="${1:-$KEEP_VERSIONS}"
  local silent="${2:-}"

  ensure_tier1_ready
  [[ -d "$IMAGES_ROOT" ]] || return 0
  [[ "$keep" =~ ^[0-9]+$ ]] || { [[ -z "$silent" ]] && log_error "GC: keep inválido: $keep"; return 2; }

  local grace_seconds="${RAGC_GC_GRACE_SECONDS:-900}"
  local snapshots_root="${RAGC_SNAPSHOTS_ROOT:-/srv/data/snapshots}"
  local snapshot_keep="${RAGC_GC_SNAPSHOT_KEEP:-7}"

  resolve_ptr() {
    local name="$1"
    local link="$IMAGES_ROOT/$name"
    [[ -L "$link" ]] || return 0
    local target=""
    target="$(readlink -f "$link" 2>/dev/null || true)"
    [[ -n "$target" && -d "$target" ]] || { [[ -z "$silent" ]] && log_error "GC: ponteiro $name quebrado ($link)"; return 1; }
    [[ "$target" == "$IMAGES_ROOT/"v* ]] || { [[ -z "$silent" ]] && log_error "GC: ponteiro $name aponta fora de $IMAGES_ROOT ($target)"; return 1; }
    basename "$target"
  }

  local current_ver=""
  current_ver="$(resolve_ptr current)" || return 2
  local previous_ver=""
  previous_ver="$(resolve_ptr previous)" || return 2
  local staged_ver=""
  staged_ver="$(resolve_ptr staged)" || return 2

  local now; now="$(date +%s)"
  local -a all_dirs=()
  local -a ranked_dirs=()
  while IFS= read -r line; do
    all_dirs+=("${line#* }")
    ranked_dirs+=("$line")
  done < <(
    find "$IMAGES_ROOT" -maxdepth 1 -mindepth 1 -type d -name 'v*' -printf '%T@ %p\n' 2>/dev/null | sort -nr
  )

  local -a preserve_ptr=()
  local -a preserve_recent=()
  local -a preserve_unknown=()
  local -a preserve_retention=()
  local -a to_remove=()

  local -A preserve_map=()
  [[ -n "$current_ver" ]] && preserve_map["$current_ver"]="ptr:current"
  [[ -n "$previous_ver" ]] && preserve_map["$previous_ver"]="ptr:previous"
  [[ -n "$staged_ver" ]] && preserve_map["$staged_ver"]="ptr:staged"

  local retention_count=0
  local entry
  for entry in "${ranked_dirs[@]}"; do
    local path="${entry#* }"
    local ver; ver="$(basename "$path")"

    if [[ -n "${preserve_map[$ver]:-}" ]]; then
      preserve_ptr+=("$ver")
      [[ -f "$path/manifest.json" ]] && (( retention_count++ )) || true
      continue
    fi

    local mtime; mtime="$(stat -c %Y "$path" 2>/dev/null || echo 0)"
    if (( now - mtime < grace_seconds )); then
      preserve_recent+=("$ver")
      [[ -f "$path/manifest.json" ]] && (( retention_count++ )) || true
      continue
    fi

    if [[ ! -f "$path/manifest.json" ]]; then
      preserve_unknown+=("$ver")
      continue
    fi

    if (( retention_count < keep )); then
      preserve_retention+=("$ver")
      (( retention_count++ )) || true
      continue
    fi

    to_remove+=("$path")
    (( retention_count++ )) || true
  done

  if (( ${#to_remove[@]} == 0 )); then
    [[ -z "$silent" ]] && log_ok "GC: nada a remover — mantidas as últimas $keep (além de ponteiros e proteções conservadoras)."
    return 0
  fi

  mkdir -p "$snapshots_root" 2>/dev/null || true
  local snapshot_name
  snapshot_name="images-pre-gc-$(date +%Y%m%d-%H%M%S-%N)"
  local snapshot_path="$snapshots_root/$snapshot_name"

  local snap_ok=0
  if command -v btrfs >/dev/null 2>&1 && btrfs subvolume show "$IMAGES_ROOT" >/dev/null 2>&1; then
    btrfs subvolume snapshot -r "$IMAGES_ROOT" "$snapshot_path" >/dev/null 2>&1 && snap_ok=1 || snap_ok=0
  fi
  if (( snap_ok == 0 )); then
    cp -al "$IMAGES_ROOT" "$snapshot_path" >/dev/null 2>&1 && snap_ok=1 || snap_ok=0
  fi

  if (( snap_ok == 0 )); then
    [[ -z "$silent" ]] && log_error "GC: snapshot falhou — recusando remoções (IMAGES_ROOT=$IMAGES_ROOT, snapshots=$snapshots_root)."
    return 3
  fi

  local removed=0
  local old
  for old in "${to_remove[@]}"; do
    local ver; ver="$(basename "$old")"
    [[ -z "$silent" ]] && log_warn "GC: removendo $ver"
    rm -rf "$old"
    (( removed++ )) || true
  done

  local -a snaps=()
  while IFS= read -r p; do
    snaps+=("$p")
  done < <(
    find "$snapshots_root" -maxdepth 1 -mindepth 1 -type d -name 'images-pre-gc-*' -printf '%T@ %p\n' 2>/dev/null \
      | sort -nr \
      | awk '{ $1=""; sub(/^ /, ""); print }'
  )

  if [[ "$snapshot_keep" =~ ^[0-9]+$ ]] && (( ${#snaps[@]} > snapshot_keep )); then
    local i
    for (( i=snapshot_keep; i<${#snaps[@]}; i++ )); do
      local s="${snaps[$i]}"
      if command -v btrfs >/dev/null 2>&1 && btrfs subvolume show "$s" >/dev/null 2>&1; then
        btrfs subvolume delete "$s" >/dev/null 2>&1 || rm -rf "$s"
      else
        rm -rf "$s"
      fi
    done
  fi

  if [[ -z "$silent" ]]; then
    log_ok "GC concluído — snapshot: $snapshot_path"
    (( ${#preserve_ptr[@]} > 0 )) && log_info "Preservado (ponteiros): ${preserve_ptr[*]}"
    (( ${#preserve_retention[@]} > 0 )) && log_info "Preservado (retenção): ${preserve_retention[*]}"
    (( ${#preserve_recent[@]} > 0 )) && log_info "Preservado (recente): ${preserve_recent[*]}"
    (( ${#preserve_unknown[@]} > 0 )) && log_info "Preservado (sem manifest): ${preserve_unknown[*]}"
    log_ok "Removido: $removed geração(ões)."
  fi
}

cmd_gc() {
  with_global_lock "ragc gc" cmd_gc_impl "${1:-$KEEP_VERSIONS}" "${2:-}"
}
