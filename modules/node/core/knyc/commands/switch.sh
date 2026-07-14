cmd_switch_impl() {
  local requested_target=""
  local requested_channel=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --target)
        shift
        [[ $# -gt 0 ]] || die "Uso: knyc switch --target <desktop-generic|desktop-lab|hyperv-debug|rescue-minimal>"
        requested_target="$1"
        ;;
      --target=*)
        requested_target="${1#--target=}"
        ;;
      --channel)
        shift
        [[ $# -gt 0 ]] || die "Uso: knyc switch [--channel <generic|lab|rescue>] [--target <...>]"
        requested_channel="$1"
        ;;
      --channel=*)
        requested_channel="${1#--channel=}"
        ;;
      "")
        ;;
      *)
        die "Argumento invalido para knyc switch: $1"
        ;;
    esac
    shift || true
  done

  local resolved_channel=""
  if [[ -n "$requested_channel" ]]; then
    resolved_channel="$(canonical_channel "$requested_channel")"
  fi

  local resolved_target
  if [[ -n "$requested_target" ]]; then
    resolved_target="$(resolve_client_target "$requested_target")"
    local target_channel_name
    target_channel_name="$(target_channel "$resolved_target")"
    if [[ -n "$resolved_channel" && "$resolved_channel" != "$target_channel_name" ]]; then
      die "Canal/target incoerentes: target '$resolved_target' pertence ao canal '$target_channel_name', nao ao canal '$resolved_channel'"
    fi
    resolved_channel="$target_channel_name"
  else
    resolved_target="$(channel_default_target "${resolved_channel:-generic}")"
    resolved_channel="$(target_channel "$resolved_target")"
  fi

  local channel_current_pointer_name
  channel_current_pointer_name="$(channel_current_pointer "$resolved_channel")"
  local channel_previous_pointer_name
  channel_previous_pointer_name="$(channel_previous_pointer "$resolved_channel")"
  local channel_staged_pointer_name
  channel_staged_pointer_name="$(channel_staged_pointer "$resolved_channel")"

  local flake_root
  flake_root="$(find_flake_root)"

  log_section "==> knyc switch"
  log_info "Flake: $flake_root"
  log_info "Target: $resolved_target"
  log_info "Canal: $resolved_channel"
  log_info "Imagens: $IMAGES_ROOT"
  log_info "HTTP: http://$SERVER_IP:$HTTP_PORT/"

  mkdir -p "$IMAGES_ROOT" "$HTTP_ROOT"
  ensure_tier1_ready
  ensure_runtime_contract_for_publish
  validate_existing_current
  clear_stale_staged_pointer

  log_info "Buildando node-client-$resolved_target..."
  local system_path
  system_path="$(build_or_reuse_system "$flake_root" "$resolved_target")"
  [[ -d "$system_path" ]] || die "Build invalido: system path ausente ($system_path)"

  local build_id
  build_id="v$(date +%Y%m%d-%H%M%S)"
  if [[ -e "$IMAGES_ROOT/$build_id" ]]; then
    build_id="${build_id}-$(date +%N)"
  fi
  local build_dir="$IMAGES_ROOT/$build_id"

  log_info "Publicando $build_id..."
  stage_generation "$build_id" "$system_path" "$resolved_target"
  log_info "Geracao $build_id criada e marcada como 'staged'."

  local current_ver=""
  local current_dir=""
  local previous_ver=""
  local previous_dir=""
  local rescue_ver=""
  local rescue_dir=""
  local rescue_init=""
  local channel_current_ver=""
  local channel_current_dir=""
  local channel_previous_dir=""

  if pointer_exists current; then
    current_ver="$(pointer_version current)"
    current_dir="$(pointer_dir current)"
    if [[ "$current_ver" == "$build_id" ]]; then
      log_warn "Geracao $build_id ja estava ativa; mantendo ponteiros coerentes."
      reconcile_generation_statuses "$build_id" "$(pointer_version previous 2>/dev/null || true)" "" "$(pointer_version rescue 2>/dev/null || true)"
      atomic_remove_path "$IMAGES_ROOT/staged"
      return 0
    fi
    previous_ver="$current_ver"
    previous_dir="$current_dir"
    log_info "previous planejado -> $previous_ver"
  fi

  if pointer_exists rescue; then
    rescue_ver="$(pointer_version rescue)"
    rescue_dir="$(pointer_dir rescue)"
    rescue_init="$(read_generation_init_path "$rescue_dir")"
  fi

  if pointer_exists "$channel_current_pointer_name"; then
    channel_current_ver="$(pointer_version "$channel_current_pointer_name")"
    channel_current_dir="$(pointer_dir "$channel_current_pointer_name")"
    if [[ "$channel_current_ver" != "$build_id" ]]; then
      channel_previous_dir="$channel_current_dir"
    fi
  fi

  ensure_generation_dir "$build_dir" "$build_id"

  if [[ "$resolved_target" == "rescue-minimal" ]]; then
    [[ -n "$current_ver" ]] || die "Nao e possivel publicar rescue sem uma geracao current ativa."

    local rescue_bundle="$HTTP_ROOT/.boot-bundle-rescue-$build_id.$$"
    trap_add "rm -rf '$rescue_bundle'"
    prepare_boot_bundle "$rescue_bundle" "$current_ver" "$(read_generation_init_path "$current_dir")" "$build_id" "$(read_generation_init_path "$build_dir")"
    validate_boot_bundle "$rescue_bundle" "$current_ver" "$build_id"
    promote_boot_bundle "$rescue_bundle"

    ensure_gc_root_for_generation "$build_dir"
    atomic_symlink "$build_dir" "$IMAGES_ROOT/rescue"
    if [[ -n "$channel_previous_dir" ]]; then
      atomic_symlink "$channel_previous_dir" "$IMAGES_ROOT/$channel_previous_pointer_name"
    fi
    atomic_symlink "$build_dir" "$IMAGES_ROOT/$channel_current_pointer_name"
    atomic_remove_path "$IMAGES_ROOT/staged"
    atomic_remove_path "$IMAGES_ROOT/$channel_staged_pointer_name"
    reconcile_generation_statuses "$current_ver" "$previous_ver" "" "$build_id"

    validate_boot_coherence "$current_ver" "$(http_get_manifest_id)"
    pointer_exists current-generic && validate_channel_boot_coherence generic "$(pointer_version current-generic)"
    pointer_exists current-lab && validate_channel_boot_coherence lab "$(pointer_version current-lab)"
    validate_rescue_coherence "$build_id"

    log_ok "rescue -> $build_id"
    log_ok "boot.ipxe/generic.ipxe/lab.ipxe/current.ipxe/rescue.ipxe atualizados"
    echo ""
    echo "  Rescue : http://$SERVER_IP:$HTTP_PORT/rescue.ipxe"
    pointer_exists current-generic && echo "  Generic: http://$SERVER_IP:$HTTP_PORT/generic.ipxe"
    pointer_exists current-lab && echo "  Lab    : http://$SERVER_IP:$HTTP_PORT/lab.ipxe"
    echo "  Target : $resolved_target"
    return 0
  fi

  local bundle_dir="$HTTP_ROOT/.boot-bundle-$build_id.$$"
  trap_add "rm -rf '$bundle_dir'"
  prepare_boot_bundle "$bundle_dir" "$build_id" "$(read_generation_init_path "$build_dir")" "$rescue_ver" "$rescue_init"
  validate_boot_bundle "$bundle_dir" "$build_id" "$rescue_ver"

  promote_boot_bundle "$bundle_dir"

  if [[ -n "$previous_dir" ]]; then
    ensure_gc_root_for_generation "$previous_dir"
    atomic_symlink "$previous_dir" "$IMAGES_ROOT/previous"
  fi

  if [[ -n "$channel_previous_dir" ]]; then
    ensure_gc_root_for_generation "$channel_previous_dir"
    atomic_symlink "$channel_previous_dir" "$IMAGES_ROOT/$channel_previous_pointer_name"
  fi

  atomic_symlink "$build_dir" "$IMAGES_ROOT/current"
  atomic_symlink "$build_dir" "$IMAGES_ROOT/$channel_current_pointer_name"
  atomic_remove_path "$IMAGES_ROOT/staged"
  atomic_remove_path "$IMAGES_ROOT/$channel_staged_pointer_name"
  reconcile_generation_statuses "$build_id" "$previous_ver" "" "$rescue_ver"
  clear_last_rollback

  validate_boot_coherence "$build_id" "$(http_get_manifest_id)"
  pointer_exists current-generic && validate_channel_boot_coherence generic "$(pointer_version current-generic)"
  pointer_exists current-lab && validate_channel_boot_coherence lab "$(pointer_version current-lab)"
  validate_rescue_coherence "$rescue_ver"

  log_ok "current -> $build_id"
  log_ok "boot.ipxe/generic.ipxe/lab.ipxe/current.ipxe/rescue.ipxe atualizados"

  cmd_gc_impl "$KEEP_VERSIONS" "silent" || log_warn "GC foi ignorado por seguranca"

  log_ok "Deploy concluido - versao ativa: $build_id"
  echo ""
  echo "  Kernel : http://$SERVER_IP:$HTTP_PORT/netboot/current/bzImage"
  echo "  Initrd : http://$SERVER_IP:$HTTP_PORT/netboot/current/initrd"
  echo "  iPXE   : http://$SERVER_IP:$HTTP_PORT/boot.ipxe"
  pointer_exists current-generic && echo "  Generic: http://$SERVER_IP:$HTTP_PORT/generic.ipxe"
  pointer_exists current-lab && echo "  Lab    : http://$SERVER_IP:$HTTP_PORT/lab.ipxe"
  [[ -n "$rescue_ver" ]] && echo "  Rescue : http://$SERVER_IP:$HTTP_PORT/rescue.ipxe"
  echo "  Target : $resolved_target"
  echo ""
  echo "  knyc rollback   - reverter se necessario"
}

cmd_switch() {
  with_global_lock "knyc switch" cmd_switch_impl "$@"
}
