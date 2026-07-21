resolve_rollback_target() {
  local requested_target="$1"
  local previous_pointer="$2"

  if [[ -n "$requested_target" ]]; then
    if [[ "$requested_target" == "previous" ]]; then
      pointer_exists "$previous_pointer" || die "Nenhuma versao anterior encontrada em '$previous_pointer'."
      pointer_version "$previous_pointer"
      return 0
    fi

    [[ -d "$IMAGES_ROOT/$requested_target" ]] || die "Versao nao encontrada: $requested_target. Use: knyc list"
    printf '%s\n' "$requested_target"
    return 0
  fi

  pointer_exists "$previous_pointer" || die "Nenhuma versao anterior encontrada em '$previous_pointer'. Use: knyc list"
  pointer_version "$previous_pointer"
}

cmd_rollback_impl() {
  local requested_target=""
  local requested_channel=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --channel)
        shift
        [[ $# -gt 0 ]] || die "Uso: knyc rollback [VERSAO|previous] [--channel <generic|lab|rescue>]"
        requested_channel="$1"
        ;;
      --channel=*)
        requested_channel="${1#--channel=}"
        ;;
      previous|v*)
        [[ -z "$requested_target" ]] || die "Somente um alvo de rollback pode ser informado"
        requested_target="$1"
        ;;
      "")
        ;;
      *)
        die "Argumento invalido para knyc rollback: $1"
        ;;
    esac
    shift || true
  done

  ensure_tier1_ready
  validate_existing_current

  local resolved_channel=""
  if [[ -n "$requested_channel" ]]; then
    resolved_channel="$(canonical_channel "$requested_channel")"
  fi

  local current_pointer="current"
  local previous_pointer="previous"
  local rescue_channel_mode="0"
  if [[ -n "$resolved_channel" ]]; then
    if [[ "$resolved_channel" == "rescue" ]]; then
      current_pointer="current-rescue"
      previous_pointer="previous-rescue"
      rescue_channel_mode="1"
    else
      current_pointer="$(channel_current_pointer "$resolved_channel")"
      previous_pointer="$(channel_previous_pointer "$resolved_channel")"
    fi
  fi

  local source_ver=""
  if [[ "$rescue_channel_mode" == "1" ]]; then
    if pointer_exists "$current_pointer"; then
      source_ver="$(pointer_version "$current_pointer")"
    elif pointer_exists rescue; then
      source_ver="$(pointer_version rescue)"
      current_pointer="rescue"
    else
      die "Nenhuma versao rescue ativa encontrada para rollback de canal."
    fi
  else
    pointer_exists "$current_pointer" || die "Nenhuma versao ativa encontrada em '$current_pointer'."
    source_ver="$(pointer_version "$current_pointer")"
  fi

  if [[ -z "$requested_target" ]] && load_last_rollback; then
    local last_channel="${channel:-}"
    if [[ ( -z "$requested_channel" || "$last_channel" == "$resolved_channel" ) ]] \
      && [[ "$source_ver" == "$target" ]] \
      && pointer_exists "$previous_pointer" \
      && [[ "$(pointer_version "$previous_pointer")" == "$source" ]]; then
      log_ok "Rollback ja aplicado anteriormente: $source -> $target"
      return 0
    fi
    clear_last_rollback
  fi

  local target_ver
  if load_pending_rollback; then
    local pending_channel="${channel:-}"

    if [[ -n "$requested_channel" && "$pending_channel" != "$resolved_channel" ]]; then
      die "Rollback pendente usa canal '$pending_channel'; resolva a operacao pendente antes de trocar o canal."
    fi
    if [[ -z "$requested_channel" && -n "$pending_channel" ]]; then
      resolved_channel="$pending_channel"
    fi
    if [[ -n "$requested_target" && "$requested_target" != "$target" && "$requested_target" != "previous" ]]; then
      die "Rollback pendente aponta para $target; resolva a operacao pendente antes de trocar o alvo."
    fi

    target_ver="$target"
    source_ver="$source"
    log_warn "Retomando rollback pendente: $source_ver -> $target_ver"
  else
    target_ver="$(resolve_rollback_target "$requested_target" "$previous_pointer")"
    write_pending_rollback "$source_ver" "$target_ver" "$resolved_channel"
  fi

  current_pointer="current"
  previous_pointer="previous"
  rescue_channel_mode="0"
  if [[ -n "$resolved_channel" ]]; then
    if [[ "$resolved_channel" == "rescue" ]]; then
      current_pointer="current-rescue"
      previous_pointer="previous-rescue"
      rescue_channel_mode="1"
    else
      current_pointer="$(channel_current_pointer "$resolved_channel")"
      previous_pointer="$(channel_previous_pointer "$resolved_channel")"
    fi
  fi

  [[ "$source_ver" != "$target_ver" ]] || {
    clear_pending_rollback
    log_ok "Rollback ja converge para $target_ver; nenhuma alteracao necessaria."
    return 0
  }

  local source_dir="$IMAGES_ROOT/$source_ver"
  local target_dir="$IMAGES_ROOT/$target_ver"
  ensure_generation_dir "$source_dir" "$source_ver"
  ensure_generation_dir "$target_dir" "$target_ver"

  if [[ "$rescue_channel_mode" == "1" ]]; then
    pointer_exists current || die "Rollback do canal rescue exige uma geracao current ativa."

    local current_ver current_dir bundle_dir
    current_ver="$(pointer_version current)"
    current_dir="$(pointer_dir current)"

    bundle_dir="$HTTP_ROOT/.boot-bundle-rollback-rescue-$target_ver.$$"
    trap_add "rm -rf '$bundle_dir'"
    prepare_boot_bundle \
      "$bundle_dir" \
      "$current_ver" \
      "$(read_generation_init_path "$current_dir")" \
      "$target_ver" \
      "$(read_generation_init_path "$target_dir")"
    validate_boot_bundle "$bundle_dir" "$current_ver" "$target_ver"
    promote_boot_bundle "$bundle_dir"

    ensure_gc_root_for_generation "$source_dir"
    ensure_gc_root_for_generation "$target_dir"
    atomic_symlink "$target_dir" "$IMAGES_ROOT/rescue"
    atomic_symlink "$target_dir" "$IMAGES_ROOT/current-rescue"
    atomic_symlink "$source_dir" "$IMAGES_ROOT/previous-rescue"
    reconcile_generation_statuses "$current_ver" "$(pointer_version previous 2>/dev/null || true)" "$(pointer_version staged 2>/dev/null || true)" "$target_ver"

    clear_pending_rollback
    write_last_rollback "$source_ver" "$target_ver" "rescue"

    validate_boot_coherence "$current_ver" "$(http_get_manifest_id)"
    pointer_exists current-generic && validate_channel_boot_coherence generic "$(pointer_version current-generic)"
    pointer_exists current-lab && validate_channel_boot_coherence lab "$(pointer_version current-lab)"
    validate_rescue_coherence "$target_ver"
    log_ok "Rollback do canal rescue concluido: $source_ver -> $target_ver"
    return 0
  fi

  local bundle_dir="$HTTP_ROOT/.boot-bundle-rollback-$target_ver.$$"
  trap_add "rm -rf '$bundle_dir'"
  local rescue_ver=""
  local rescue_init=""
  if pointer_exists rescue; then
    rescue_ver="$(pointer_version rescue)"
    rescue_init="$(read_generation_init_path "$(pointer_dir rescue)")"
  fi
  prepare_boot_bundle \
    "$bundle_dir" \
    "$target_ver" \
    "$(read_generation_init_path "$target_dir")" \
    "$rescue_ver" \
    "$rescue_init"
  validate_boot_bundle "$bundle_dir" "$target_ver" "$rescue_ver"
  promote_boot_bundle "$bundle_dir"

  ensure_gc_root_for_generation "$source_dir"
  ensure_gc_root_for_generation "$target_dir"
  atomic_symlink "$target_dir" "$IMAGES_ROOT/current"
  atomic_symlink "$source_dir" "$IMAGES_ROOT/previous"

  if [[ -n "$resolved_channel" ]]; then
    atomic_symlink "$target_dir" "$IMAGES_ROOT/$current_pointer"
    atomic_symlink "$source_dir" "$IMAGES_ROOT/$previous_pointer"
  else
    local inferred_channel=""
    inferred_channel="$(manifest_read_field "$target_dir/manifest.json" channel)"
    if [[ -n "$inferred_channel" ]]; then
      local inferred_current inferred_previous
      inferred_current="$(channel_current_pointer "$inferred_channel")"
      inferred_previous="$(channel_previous_pointer "$inferred_channel")"
      atomic_symlink "$target_dir" "$IMAGES_ROOT/$inferred_current"
      atomic_symlink "$source_dir" "$IMAGES_ROOT/$inferred_previous"
      resolved_channel="$inferred_channel"
    fi
  fi

  reconcile_generation_statuses "$target_ver" "$source_ver" "$(pointer_version staged 2>/dev/null || true)" "$(pointer_version rescue 2>/dev/null || true)"
  clear_pending_rollback
  write_last_rollback "$source_ver" "$target_ver" "$resolved_channel"

  validate_boot_coherence "$target_ver" "$(http_get_manifest_id)"
  pointer_exists current-generic && validate_channel_boot_coherence generic "$(pointer_version current-generic)"
  pointer_exists current-lab && validate_channel_boot_coherence lab "$(pointer_version current-lab)"
  validate_rescue_coherence "$(pointer_version rescue 2>/dev/null || true)"
  log_ok "Rollback concluido: $source_ver -> $target_ver"
}

cmd_rollback() {
  with_global_lock "knyc rollback" cmd_rollback_impl "$@"
}
