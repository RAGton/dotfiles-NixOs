manifest_path() {
  local generation_dir="$1"
  echo "$generation_dir/manifest.json"
}

manifest_read_field() {
  local manifest="$1"
  local field="$2"
  grep -E "\"$field\"[[:space:]]*:" "$manifest" 2>/dev/null | head -n1 | cut -d'"' -f4
}

write_generation_manifest() {
  local generation_dir="$1"
  local build_id="$2"
  local system_path="$3"
  local init_path="$4"
  local status="$5"
  local target_name="$6"
  local channel_name="$7"
  local hardware_class="$8"
  local manifest_tmp="$generation_dir/manifest.json.tmp.$$"

  cat > "$manifest_tmp" <<JSON
{
  "id": "$build_id",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "system_path": "$system_path",
  "init_path": "$init_path",
  "artifacts": {
    "kernel": "bzImage",
    "initrd": "initrd"
  },
  "checksums": {
    "kernel": "$(sha256sum "$generation_dir/bzImage" | awk '{print $1}')",
    "initrd": "$(sha256sum "$generation_dir/initrd" | awk '{print $1}')"
  },
  "status": "$status",
  "target": "$target_name",
  "channel": "$channel_name",
  "hardwareClass": "$hardware_class"
}
JSON

  mv -f "$manifest_tmp" "$generation_dir/manifest.json"
}

validate_manifest() {
  local generation_dir="$1"
  local expected_id="$2"
  local manifest
  manifest="$(manifest_path "$generation_dir")"

  [[ -f "$manifest" ]] || die "Manifest ausente: $manifest"
  [[ "$(manifest_read_field "$manifest" id)" == "$expected_id" ]] || die "Manifest invalido em $manifest: id divergente"
  if [[ "${KNYC_ALLOW_NON_NIX_STORE_PATHS:-0}" != "1" ]]; then
    [[ "$(manifest_read_field "$manifest" system_path)" =~ ^/nix/store/ ]] || die "Manifest invalido em $manifest: system_path ausente"
    [[ "$(manifest_read_field "$manifest" init_path)" =~ ^/nix/store/ ]] || die "Manifest invalido em $manifest: init_path ausente"
  fi

  local kernel_checksum
  kernel_checksum="$(grep -E '"kernel"[[:space:]]*:' "$manifest" 2>/dev/null | tail -n1 | cut -d'"' -f4)"
  local initrd_checksum
  initrd_checksum="$(grep -E '"initrd"[[:space:]]*:' "$manifest" 2>/dev/null | tail -n1 | cut -d'"' -f4)"
  local channel_name
  channel_name="$(manifest_read_field "$manifest" channel)"
  local hardware_class
  hardware_class="$(manifest_read_field "$manifest" hardwareClass)"

  [[ -n "$kernel_checksum" ]] || die "Manifest invalido em $manifest: checksum do kernel ausente"
  [[ -n "$initrd_checksum" ]] || die "Manifest invalido em $manifest: checksum do initrd ausente"
  [[ -n "$channel_name" ]] || die "Manifest invalido em $manifest: channel ausente"
  [[ -n "$hardware_class" ]] || die "Manifest invalido em $manifest: hardwareClass ausente"

  [[ "$(sha256sum "$generation_dir/bzImage" | awk '{print $1}')" == "$kernel_checksum" ]] || die "Manifest invalido em $manifest: checksum do kernel divergente"
  [[ "$(sha256sum "$generation_dir/initrd" | awk '{print $1}')" == "$initrd_checksum" ]] || die "Manifest invalido em $manifest: checksum do initrd divergente"
}

set_generation_status() {
  local generation_dir="$1"
  local new_status="$2"
  local manifest
  manifest="$(manifest_path "$generation_dir")"
  [[ -f "$manifest" ]] || return 0

  local tmp="${manifest}.tmp.$$"
  sed -E 's/"status"[[:space:]]*:[[:space:]]*"[^"]+"/"status": "'"$new_status"'"/' "$manifest" > "$tmp"
  mv -f "$tmp" "$manifest"
}

reconcile_generation_statuses() {
  local current_ver="$1"
  local previous_ver="$2"
  local staged_ver="$3"
  local rescue_ver="$4"
  local dir

  for dir in "$IMAGES_ROOT"/v*; do
    [[ -d "$dir" ]] || continue
    local ver
    ver="$(basename "$dir")"
    local status="inactive"

    if [[ -n "$staged_ver" && "$ver" == "$staged_ver" ]]; then
      status="staged"
    elif [[ -n "$current_ver" && "$ver" == "$current_ver" ]]; then
      status="active"
    elif [[ -n "$previous_ver" && "$ver" == "$previous_ver" ]]; then
      status="previous"
    elif [[ -n "$rescue_ver" && "$ver" == "$rescue_ver" ]]; then
      status="rescue"
    fi

    set_generation_status "$dir" "$status"
  done
}
