cmd_doctor() {
  log_section "RAGOS Infrastructure Check"
  echo ""

  DOCTOR_OK=0
  DOCTOR_FAIL=0

  check_service dnsmasq
  check_service nginx
  check_service nfs-server

  if storage_mount_ready; then
    print_check "tier1 mount" "OK"
    (( DOCTOR_OK++ )) || true
  else
    print_check "tier1 mount" "FAIL"
    (( DOCTOR_FAIL++ )) || true
  fi

  check_dir "$DATA_ROOT" "srv/data"
  check_dir "$IMAGES_ROOT" "images dir"
  check_dir "$DATA_ROOT/home" "home dir"
  check_dir "$HTTP_ROOT" "http root"

  check_file "$TFTP_ROOT/EFI/BOOT/BOOTX64.EFI" "BOOTX64.EFI"
  check_symlink "$HTTP_ROOT/netboot" "netboot link"
  check_file "$HTTP_ROOT/boot.ipxe" "boot.ipxe"
  check_file "$HTTP_ROOT/generic.ipxe" "generic.ipxe"
  check_file "$HTTP_ROOT/lab.ipxe" "lab.ipxe"
  check_file "$HTTP_ROOT/current.ipxe" "current.ipxe"
  check_file "$HTTP_ROOT/rescue.ipxe" "rescue.ipxe"

  local current_ver=""
  local current_dir=""

  if pointer_exists current; then
    check_symlink "$IMAGES_ROOT/current" "current link"
    current_ver="$(pointer_version current)"
    current_dir="$(pointer_dir current)"
    check_file "$current_dir/bzImage" "current bzImage"
    check_file "$current_dir/initrd" "current initrd"
    check_file "$current_dir/manifest.json" "current manifest"
    if command -v nix-store >/dev/null 2>&1 && [[ "${RAGC_ALLOW_NON_NIX_STORE_PATHS:-0}" != "1" ]]; then
      check_path_exists "$current_dir/.gcroot" "current gcroot"
    fi

    if [[ "$(manifest_read_field "$current_dir/manifest.json" id)" == "$current_ver" ]]; then
      print_check "manifest current id" "OK"
      (( DOCTOR_OK++ )) || true
    else
      print_check "manifest current id" "FAIL"
      (( DOCTOR_FAIL++ )) || true
    fi
  else
    print_check "current link" "FAIL"
    (( DOCTOR_FAIL++ )) || true
  fi

  local previous_ver=""
  if pointer_exists previous; then
    check_symlink "$IMAGES_ROOT/previous" "previous link"
    previous_ver="$(pointer_version previous)"
    local previous_dir
    previous_dir="$(pointer_dir previous)"
    check_file "$previous_dir/manifest.json" "previous manifest"
    if command -v nix-store >/dev/null 2>&1 && [[ "${RAGC_ALLOW_NON_NIX_STORE_PATHS:-0}" != "1" ]]; then
      check_path_exists "$previous_dir/.gcroot" "previous gcroot"
    fi
  fi

  local rescue_ver=""
  if pointer_exists rescue; then
    check_symlink "$IMAGES_ROOT/rescue" "rescue link"
    rescue_ver="$(pointer_version rescue)"
    local rescue_dir
    rescue_dir="$(pointer_dir rescue)"
    check_file "$rescue_dir/manifest.json" "rescue manifest"
    if command -v nix-store >/dev/null 2>&1 && [[ "${RAGC_ALLOW_NON_NIX_STORE_PATHS:-0}" != "1" ]]; then
      check_path_exists "$rescue_dir/.gcroot" "rescue gcroot"
    fi
  fi

  local staged_ver=""
  if pointer_exists staged; then
    check_symlink "$IMAGES_ROOT/staged" "staged link"
    staged_ver="$(pointer_version staged)"
    local staged_dir
    staged_dir="$(pointer_dir staged)"
    check_file "$staged_dir/manifest.json" "staged manifest"
  fi

  local channel
  for channel in generic lab rescue; do
    local current_ptr="current-$channel"
    local previous_ptr="previous-$channel"
    local staged_ptr="staged-$channel"

    if pointer_exists "$current_ptr"; then
      check_symlink "$IMAGES_ROOT/$current_ptr" "$current_ptr link"
    fi
    if pointer_exists "$previous_ptr"; then
      check_symlink "$IMAGES_ROOT/$previous_ptr" "$previous_ptr link"
    fi
    if pointer_exists "$staged_ptr"; then
      check_symlink "$IMAGES_ROOT/$staged_ptr" "$staged_ptr link"
    fi
  done

  local active_count=0
  local dir
  for dir in "$IMAGES_ROOT"/v*; do
    [[ -d "$dir" ]] || continue
    local status
    status="$(manifest_read_field "$dir/manifest.json" status)"
    [[ "$status" == "active" ]] && (( active_count++ )) || true
  done

  if [[ "$active_count" -eq 1 ]]; then
    print_check "active manifest count" "OK"
    (( DOCTOR_OK++ )) || true
  else
    print_check "active manifest count" "FAIL"
    (( DOCTOR_FAIL++ )) || true
  fi

  local grace_seconds="${RAGC_GC_GRACE_SECONDS:-900}"
  local now
  now="$(date +%s)"
  for dir in "$IMAGES_ROOT"/v*; do
    [[ -d "$dir" ]] || continue
    if [[ ! -f "$dir/manifest.json" ]]; then
      local mtime
      mtime="$(stat -c %Y "$dir" 2>/dev/null || echo 0)"
      if (( now - mtime >= grace_seconds )); then
        print_check "orphan $(basename "$dir")" "FAIL"
        (( DOCTOR_FAIL++ )) || true
      fi
    fi
  done

  check_http "http://$SERVER_IP:$HTTP_PORT/boot.ipxe" "http boot"
  check_http "http://$SERVER_IP:$HTTP_PORT/generic.ipxe" "http generic"
  check_http "http://$SERVER_IP:$HTTP_PORT/lab.ipxe" "http lab"
  check_http "http://$SERVER_IP:$HTTP_PORT/current.ipxe" "http current"
  check_http "http://$SERVER_IP:$HTTP_PORT/netboot/current/manifest.json" "http manifest"

  if [[ -n "$current_ver" ]]; then
    local http_manifest
    http_manifest="$(http_get_manifest_id)"
    if validate_boot_coherence "$current_ver" "$http_manifest" 2>/dev/null; then
      print_check "boot coherence" "OK"
      (( DOCTOR_OK++ )) || true
    else
      print_check "boot coherence" "FAIL"
      (( DOCTOR_FAIL++ )) || true
    fi
  fi

  if [[ -n "$rescue_ver" ]]; then
    local rescue_declared
    rescue_declared="$(ipxe_declared_value "$HTTP_ROOT/rescue.ipxe" build_id)"
    if [[ "$rescue_declared" == "$rescue_ver" ]]; then
      print_check "rescue coherence" "OK"
      (( DOCTOR_OK++ )) || true
    else
      print_check "rescue coherence" "FAIL"
      (( DOCTOR_FAIL++ )) || true
    fi
  fi

  if pointer_exists current-generic; then
    if validate_channel_boot_coherence generic "$(pointer_version current-generic)" 2>/dev/null; then
      print_check "generic coherence" "OK"
      (( DOCTOR_OK++ )) || true
    else
      print_check "generic coherence" "FAIL"
      (( DOCTOR_FAIL++ )) || true
    fi
  fi

  if pointer_exists current-lab; then
    if validate_channel_boot_coherence lab "$(pointer_version current-lab)" 2>/dev/null; then
      print_check "lab coherence" "OK"
      (( DOCTOR_OK++ )) || true
    else
      print_check "lab coherence" "FAIL"
      (( DOCTOR_FAIL++ )) || true
    fi
  fi

  if systemctl is-active --quiet grafana 2>/dev/null; then
    check_http "http://$SERVER_IP:3000" "grafana"
  fi

  echo ""
  if [[ "$DOCTOR_FAIL" -eq 0 ]]; then
    log_ok "RAGOS server healthy"
    return 0
  fi

  log_error "RAGOS server has issues ($DOCTOR_FAIL falha(s))"
  echo ""
  echo "Dicas:"
  echo "  - Verifique servicos: systemctl status dnsmasq nginx nfs-server"
  echo "  - Execute ragc list e valide current/previous/staged"
  echo "  - Corrija qualquer divergencia antes de promover nova geracao"
  return 1
}
