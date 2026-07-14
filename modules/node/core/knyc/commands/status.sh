cmd_status() {
  log_section "Status KNYC"
  echo ""
  echo "  Servidor  : $SERVER_IP"
  echo "  HTTP Port : $HTTP_PORT"
  echo "  Imagens   : $IMAGES_ROOT"
  echo "  HTTP Root : $HTTP_ROOT"
  echo ""

  if pointer_exists current; then
    local ver; ver="$(pointer_version current)"
    local init; init="$(cat "$IMAGES_ROOT/$ver/.init_path" 2>/dev/null || echo "desconhecido")"
    local target="desconhecido"
    local channel="desconhecido"
    local hardware_class="desconhecido"
    [[ -f "$IMAGES_ROOT/$ver/manifest.json" ]] && target="$(manifest_read_field "$IMAGES_ROOT/$ver/manifest.json" target)"
    [[ -f "$IMAGES_ROOT/$ver/manifest.json" ]] && channel="$(manifest_read_field "$IMAGES_ROOT/$ver/manifest.json" channel)"
    [[ -f "$IMAGES_ROOT/$ver/manifest.json" ]] && hardware_class="$(manifest_read_field "$IMAGES_ROOT/$ver/manifest.json" hardwareClass)"
    
    echo -e "  Versão ativa : ${GREEN}$ver${NC}"
    echo "  Target ativo : $target"
    echo "  Canal ativo  : $channel"
    echo "  Classe HW    : $hardware_class"
    
    if [[ -f "$IMAGES_ROOT/$ver/manifest.json" ]]; then
      local ts; ts="$(grep '"timestamp":' "$IMAGES_ROOT/$ver/manifest.json" | cut -d'"' -f4)"
      local sp; sp="$(grep '"system_path":' "$IMAGES_ROOT/$ver/manifest.json" | cut -d'"' -f4)"
      echo "  Timestamp    : $ts"
      echo "  System path  : $sp"
    fi

    echo "  Init path    : $init"
    echo "  Kernel URL   : http://$SERVER_IP:$HTTP_PORT/netboot/current/bzImage"
    echo "  Initrd URL   : http://$SERVER_IP:$HTTP_PORT/netboot/current/initrd"
    echo "  iPXE URL     : http://$SERVER_IP:$HTTP_PORT/boot.ipxe"
    [[ -f "$HTTP_ROOT/generic.ipxe" ]] && echo "  Generic URL  : http://$SERVER_IP:$HTTP_PORT/generic.ipxe"
    [[ -f "$HTTP_ROOT/lab.ipxe" ]] && echo "  Lab URL      : http://$SERVER_IP:$HTTP_PORT/lab.ipxe"
    [[ -f "$HTTP_ROOT/rescue.ipxe" ]] && echo "  Rescue URL   : http://$SERVER_IP:$HTTP_PORT/rescue.ipxe"
  else
    log_warn "Nenhuma versão ativa. Execute: knyc switch"
  fi

  if pointer_exists previous; then
    echo -e "  Versão ant.  : ${YELLOW}$(pointer_version previous)${NC}"
  fi

  if pointer_exists rescue; then
    echo -e "  Versão rescue: ${BLUE}$(pointer_version rescue)${NC}"
  fi

  if pointer_exists staged; then
    echo -e "  Versão staged: ${BLUE}$(pointer_version staged)${NC}"
  fi

  for channel in generic lab rescue; do
    local current_ptr="current-$channel"
    local previous_ptr="previous-$channel"
    local staged_ptr="staged-$channel"
    if pointer_exists "$current_ptr"; then
      echo "  Canal $channel current : $(pointer_version "$current_ptr")"
    fi
    if pointer_exists "$previous_ptr"; then
      echo "  Canal $channel previous: $(pointer_version "$previous_ptr")"
    fi
    if pointer_exists "$staged_ptr"; then
      echo "  Canal $channel staged  : $(pointer_version "$staged_ptr")"
    fi
  done

  echo ""
  local count
  count="$(find "$IMAGES_ROOT" -maxdepth 1 -mindepth 1 -type d -name 'v*' 2>/dev/null | wc -l | awk '{print $1}')"
  echo "  Versões armazenadas: $count"
}
