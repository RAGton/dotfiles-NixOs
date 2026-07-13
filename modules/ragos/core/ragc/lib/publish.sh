RAGC_ROLLBACK_PENDING_PATH="${RAGC_ROLLBACK_PENDING_PATH:-$IMAGES_ROOT/.rollback.pending}"
RAGC_LAST_ROLLBACK_PATH="${RAGC_LAST_ROLLBACK_PATH:-$IMAGES_ROOT/.rollback.last}"

target_channel() {
  local target="$1"
  case "$target" in
    desktop-generic)
      printf '%s\n' "generic"
      ;;
    desktop-lab|hyperv-debug)
      printf '%s\n' "lab"
      ;;
    rescue-minimal)
      printf '%s\n' "rescue"
      ;;
    *)
      die "Target sem canal conhecido: $target"
      ;;
  esac
}

target_hardware_class() {
  local target="$1"
  case "$target" in
    desktop-generic)
      printf '%s\n' "physical-generic"
      ;;
    desktop-lab)
      printf '%s\n' "physical-lab"
      ;;
    hyperv-debug)
      printf '%s\n' "hyperv"
      ;;
    rescue-minimal)
      printf '%s\n' "rescue"
      ;;
    *)
      die "Target sem classe de hardware conhecida: $target"
      ;;
  esac
}

canonical_channel() {
  local requested_channel="$1"

  case "$requested_channel" in
    ""|generic|lab|rescue)
      printf '%s\n' "${requested_channel:-generic}"
      ;;
    *)
      die "Canal invalido: $requested_channel. Use: generic, lab ou rescue"
      ;;
  esac
}

channel_default_target() {
  local channel
  channel="$(canonical_channel "$1")"

  case "$channel" in
    generic)
      printf '%s\n' "desktop-generic"
      ;;
    lab)
      printf '%s\n' "desktop-lab"
      ;;
    rescue)
      printf '%s\n' "rescue-minimal"
      ;;
  esac
}

channel_current_pointer() {
  local channel
  channel="$(canonical_channel "$1")"
  printf '%s\n' "current-$channel"
}

channel_previous_pointer() {
  local channel
  channel="$(canonical_channel "$1")"
  printf '%s\n' "previous-$channel"
}

channel_staged_pointer() {
  local channel
  channel="$(canonical_channel "$1")"
  printf '%s\n' "staged-$channel"
}

active_channel_from_current() {
  if ! pointer_exists current; then
    printf '%s\n' ""
    return 0
  fi

  local current_ver manifest channel
  current_ver="$(pointer_version current)"
  manifest="$IMAGES_ROOT/$current_ver/manifest.json"
  channel="$(manifest_read_field "$manifest" channel)"
  printf '%s\n' "$channel"
}

runtime_source_from_params_file() {
  local params_file="$1"
  awk -F'"' '/runtimeSource[[:space:]]*=/{print $2; exit}' "$params_file" 2>/dev/null || true
}

ensure_runtime_contract_for_publish() {
  [[ -n "${RAGC_TEST_SYSTEM_PATH:-}" ]] && return 0

  local runtime_root="${RAGOS_RUNTIME_ROOT:-/var/lib/ragos/runtime}"
  local params_file="$runtime_root/params.nix"

  [[ -f "$params_file" ]] || die "Runtime ausente: publicacao oficial exige $params_file"

  local runtime_source
  runtime_source="$(runtime_source_from_params_file "$params_file")"
  [[ "$runtime_source" == "runtime" ]] || die "Runtime invalido para publicacao oficial: runtimeSource=$runtime_source (esperado: runtime)"
}

resolve_client_target() {
  local requested_target="${1:-}"

  if [[ -z "$requested_target" ]]; then
    requested_target="$DEFAULT_CLIENT_TARGET"
  fi

  case "$requested_target" in
    desktop-generic|generic)
      printf '%s\n' "desktop-generic"
      ;;
    physical-generic)
      log_warn "Alias legado 'physical-generic' detectado; use 'desktop-generic'"
      printf '%s\n' "desktop-generic"
      ;;
    desktop-lab|lab)
      printf '%s\n' "desktop-lab"
      ;;
    hyperv-debug)
      printf '%s\n' "hyperv-debug"
      ;;
    rescue-minimal|rescue)
      [[ "$requested_target" == "rescue" ]] && log_warn "Alias legado 'rescue' detectado; use 'rescue-minimal'"
      printf '%s\n' "rescue-minimal"
      ;;
    *)
      die "Target invalido: $requested_target. Use: desktop-generic, desktop-lab, hyperv-debug ou rescue-minimal"
      ;;
  esac
}

target_installable() {
  local flake_root="$1"
  local requested_target="$2"
  local resolved_target
  local flake_ref
  resolved_target="$(resolve_client_target "$requested_target")"
  flake_ref="$flake_root"

  # Checkouts operacionais materializados em /etc/ragos podem manter .git/.gitmodules
  # sem os metadados completos de submodulo. Prefixar como path evita que o Nix
  # reinterprete o che00ckout como git+file e tente refazer o submodulo installer.
  if [[ "$flake_ref" != *:* ]]; then
    flake_ref="path:$(realpath -m "$flake_ref")"
  fi

  case "$resolved_target" in
    desktop-generic)
      printf '%s\n' "$flake_ref#nixosConfigurations.ragos-client-desktop-generic.config.system.build.ragosPublishTree"
      ;;
    desktop-lab)
      printf '%s\n' "$flake_ref#nixosConfigurations.ragos-client-desktop-lab.config.system.build.ragosPublishTree"
      ;;
    hyperv-debug)
      printf '%s\n' "$flake_ref#nixosConfigurations.ragos-client-hyperv-debug.config.system.build.ragosPublishTree"
      ;;
    rescue-minimal)
      printf '%s\n' "$flake_ref#nixosConfigurations.ragos-client-rescue-minimal.config.system.build.ragosPublishTree"
      ;;
  esac
}

storage_mount_ready() {
  [[ "${RAGC_SKIP_STORAGE_CHECKS:-0}" == "1" ]] && return 0
  mountpoint -q "$DATA_ROOT" 2>/dev/null || mountpoint -q "$IMAGES_ROOT" 2>/dev/null
}

ensure_tier1_ready() {
  [[ "${RAGC_SKIP_STORAGE_CHECKS:-0}" == "1" ]] && return 0

  [[ -d "$IMAGES_ROOT" ]] || die "Tier 1 indisponivel: diretorio de imagens ausente ($IMAGES_ROOT)"
  [[ -d "$HTTP_ROOT" ]] || die "HTTP root ausente: $HTTP_ROOT"
  storage_mount_ready || die "Tier 1 indisponivel: $DATA_ROOT nao esta montado de forma pronta para operacao"
}

ensure_generation_dir() {
  local generation_dir="$1"
  local generation_id="$2"

  [[ -d "$generation_dir" ]] || die "Geracao ausente: $generation_dir"
  [[ -f "$generation_dir/bzImage" ]] || die "Artefato incompleto: bzImage ausente em $generation_dir"
  [[ -f "$generation_dir/initrd" ]] || die "Artefato incompleto: initrd ausente em $generation_dir"
  [[ -f "$generation_dir/.init_path" ]] || die "Artefato incompleto: .init_path ausente em $generation_dir"
  [[ -f "$generation_dir/.kernel_params" ]] || die "Artefato incompleto: .kernel_params ausente em $generation_dir"
  validate_manifest "$generation_dir" "$generation_id"
}

pointer_exists() {
  local name="$1"
  [[ -L "$IMAGES_ROOT/$name" ]]
}

pointer_version() {
  local name="$1"
  local link="$IMAGES_ROOT/$name"
  [[ -L "$link" ]] || return 1

  local target
  target="$(readlink -f "$link" 2>/dev/null || true)"
  [[ -n "$target" && -d "$target" ]] || die "Ponteiro quebrado: $name -> $target"
  [[ "$target" == "$IMAGES_ROOT/"v* ]] || die "Ponteiro invalido: $name aponta para fora de $IMAGES_ROOT ($target)"
  basename "$target"
}

pointer_dir() {
  local name="$1"
  local ver
  ver="$(pointer_version "$name")" || return 1
  echo "$IMAGES_ROOT/$ver"
}

read_generation_init_path() {
  local generation_dir="$1"
  [[ -f "$generation_dir/.init_path" ]] || die "Init path ausente em $generation_dir"
  cat "$generation_dir/.init_path"
}

read_generation_kernel_params() {
  local generation_dir="$1"
  [[ -f "$generation_dir/.kernel_params" ]] || die "Kernel params ausentes em $generation_dir"
  tr '\n' ' ' < "$generation_dir/.kernel_params" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}

atomic_symlink() {
  local target="$1"
  local link="$2"
  local tmp="${link}.tmp.$$.$RANDOM"

  ln -s "$target" "$tmp"
  mv -Tf "$tmp" "$link"
}

atomic_remove_path() {
  local path="$1"
  if [[ -L "$path" || -e "$path" ]]; then
    local tomb="${path}.delete.$$.$RANDOM"
    mv -Tf "$path" "$tomb"
    rm -rf "$tomb"
  fi
}

clear_stale_staged_pointer() {
  if pointer_exists staged; then
      local staged_ver
      staged_ver="$(pointer_version staged)"
      if [[ -n "$staged_ver" ]]; then
        log_warn "Removendo ponteiro staged residual: $staged_ver"
        atomic_remove_path "$IMAGES_ROOT/staged"
        reconcile_generation_statuses "$(pointer_version current 2>/dev/null || true)" "$(pointer_version previous 2>/dev/null || true)" "" "$(pointer_version rescue 2>/dev/null || true)"
      fi
  fi

  local channel
  for channel in generic lab rescue; do
    local staged_pointer
    staged_pointer="$(channel_staged_pointer "$channel")"
    if pointer_exists "$staged_pointer"; then
      local staged_channel_ver
      staged_channel_ver="$(pointer_version "$staged_pointer")"
      if [[ -n "$staged_channel_ver" ]]; then
        log_warn "Removendo ponteiro $staged_pointer residual: $staged_channel_ver"
        atomic_remove_path "$IMAGES_ROOT/$staged_pointer"
      fi
    fi
  done
}

http_get_manifest_id() {
  curl -fsS --max-time 3 "http://127.0.0.1:$HTTP_PORT/netboot/current/manifest.json" 2>/dev/null || true
}

validate_existing_current() {
  if pointer_exists current; then
    local current_ver current_dir
    current_ver="$(pointer_version current)"
    current_dir="$(pointer_dir current)"
    ensure_generation_dir "$current_dir" "$current_ver"
  fi
}

create_gc_root() {
  local generation_dir="$1"
  local system_path="$2"

  if command -v nix-store >/dev/null 2>&1; then
    nix-store --add-root "$generation_dir/.gcroot" -r "$system_path" >/dev/null 2>&1 || log_warn "GC root nao pode ser criado para $(basename "$generation_dir")"
  else
    log_warn "nix-store indisponivel; /nix/store pode ser coletado e quebrar boots antigos"
  fi
}

ensure_gc_root_for_generation() {
  local generation_dir="$1"
  [[ -d "$generation_dir" ]] || return 0
  [[ -f "$generation_dir/.gcroot" ]] && return 0

  local manifest
  manifest="$(manifest_path "$generation_dir")"
  [[ -f "$manifest" ]] || return 0

  local system_path
  system_path="$(manifest_read_field "$manifest" system_path)"
  [[ -n "$system_path" ]] || return 0

  create_gc_root "$generation_dir" "$system_path"
}

build_or_reuse_system() {
  local flake_root="$1"
  local requested_target="$2"
  local result_link="$flake_root/.ragc-build-result"

  rm -f "$result_link"
  trap_add "rm -f '$result_link'"

  if [[ -n "${RAGC_TEST_SYSTEM_PATH:-}" ]]; then
    printf '%s\n' "$RAGC_TEST_SYSTEM_PATH"
    return 0
  fi

  nix build --impure "$(target_installable "$flake_root" "$requested_target")" \
    --out-link "$result_link" \
    || die "Falha no build NixOS"

  readlink -f "$result_link"
}

stage_generation() {
  local build_id="$1"
  local publish_tree="$2"
  local target_name="$3"
  local channel_pointer
  local channel_name
  local hardware_class
  local generation_dir="$IMAGES_ROOT/$build_id"
  local system_path="$publish_tree"
  local init_path="$publish_tree/init"
  local kernel_params_path="$publish_tree/kernel-params"

  [[ -e "$publish_tree/kernel" ]] || die "Artefato de publish invalido: kernel ausente em $publish_tree"
  [[ -e "$publish_tree/initrd" ]] || die "Artefato de publish invalido: initrd ausente em $publish_tree"
  [[ -e "$init_path" ]] || die "Artefato de publish invalido: init ausente em $publish_tree"
  [[ -e "$kernel_params_path" ]] || die "Artefato de publish invalido: kernel-params ausente em $publish_tree"

  if [[ -e "$publish_tree/toplevel" ]]; then
    system_path="$(readlink -f "$publish_tree/toplevel")"
  fi
  init_path="$(readlink -f "$init_path" 2>/dev/null || printf '%s\n' "$init_path")"

  channel_name="$(target_channel "$target_name")"
  channel_pointer="$(channel_staged_pointer "$channel_name")"
  hardware_class="$(target_hardware_class "$target_name")"

  mkdir -p "$generation_dir"
  cp -L "$publish_tree/kernel" "$generation_dir/bzImage"
  cp -L "$publish_tree/initrd" "$generation_dir/initrd"
  printf '%s\n' "$init_path" > "$generation_dir/.init_path"
  cp -L "$kernel_params_path" "$generation_dir/.kernel_params"

  create_gc_root "$generation_dir" "$system_path"
  write_generation_manifest "$generation_dir" "$build_id" "$system_path" "$init_path" "staged" "$target_name" "$channel_name" "$hardware_class"
  validate_manifest "$generation_dir" "$build_id"

  atomic_symlink "$generation_dir" "$IMAGES_ROOT/staged"
  atomic_symlink "$generation_dir" "$IMAGES_ROOT/$channel_pointer"
  maybe_test_pause "after-stage"
}

write_pending_rollback() {
  local source_ver="$1"
  local target_ver="$2"
  local channel_name="${3:-}"
  local tmp="${RAGC_ROLLBACK_PENDING_PATH}.tmp.$$"

  cat > "$tmp" <<EOF
source=$source_ver
target=$target_ver
channel=$channel_name
EOF
  mv -f "$tmp" "$RAGC_ROLLBACK_PENDING_PATH"
}

load_pending_rollback() {
  [[ -f "$RAGC_ROLLBACK_PENDING_PATH" ]] || return 1
  # shellcheck disable=SC1090
  source "$RAGC_ROLLBACK_PENDING_PATH"
  [[ -n "${source:-}" && -n "${target:-}" ]]
}

clear_pending_rollback() {
  rm -f "$RAGC_ROLLBACK_PENDING_PATH"
}

write_last_rollback() {
  local source_ver="$1"
  local target_ver="$2"
  local channel_name="${3:-}"
  local tmp="${RAGC_LAST_ROLLBACK_PATH}.tmp.$$"

  cat > "$tmp" <<EOF
source=$source_ver
target=$target_ver
channel=$channel_name
EOF
  mv -f "$tmp" "$RAGC_LAST_ROLLBACK_PATH"
}

load_last_rollback() {
  [[ -f "$RAGC_LAST_ROLLBACK_PATH" ]] || return 1
  # shellcheck disable=SC1090
  source "$RAGC_LAST_ROLLBACK_PATH"
  [[ -n "${source:-}" && -n "${target:-}" ]]
}

clear_last_rollback() {
  rm -f "$RAGC_LAST_ROLLBACK_PATH"
}
