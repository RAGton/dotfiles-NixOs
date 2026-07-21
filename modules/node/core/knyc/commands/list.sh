cmd_list() {
  log_section "Versões em $IMAGES_ROOT"
  echo ""

  [[ -d "$IMAGES_ROOT" ]] || { log_warn "Nenhuma versão publicada ainda."; return; }

  local current=""
  pointer_exists current && current="$(pointer_version current)"

  local previous=""
  pointer_exists previous && previous="$(pointer_version previous)"

  local rescue=""
  pointer_exists rescue && rescue="$(pointer_version rescue)"

  local staged=""
  pointer_exists staged && staged="$(pointer_version staged)"

  local count=0
  for d in "$IMAGES_ROOT"/v*/; do
    [[ -d "$d" ]] || continue
    local ver; ver="$(basename "$d")"
    local size; size="$(du -sh "$d" 2>/dev/null | awk '{print $1}')"
    local meta=""
    [[ "$ver" == "$current" ]] && meta="${GREEN}* ativo${NC}"
    [[ "$ver" == "$previous" ]] && meta="${YELLOW}anterior${NC}"
    [[ "$ver" == "$rescue" ]] && meta="${BLUE}rescue${NC}"
    [[ "$ver" == "$staged" ]] && meta="${BLUE}staged${NC}"

    local timestamp=""
    local target=""
    local channel=""
    local hardware_class=""
    if [[ -f "$d/manifest.json" ]]; then
       timestamp=$(grep '"timestamp":' "$d/manifest.json" | cut -d'"' -f4 | cut -d'T' -f1)
       # Adicionar a hora também para melhor precisão visual
       local time_part; time_part=$(grep '"timestamp":' "$d/manifest.json" | cut -d'"' -f4 | cut -d'T' -f2 | cut -d'Z' -f1 | cut -d':' -f1,2)
       timestamp="$timestamp $time_part"
       target="$(manifest_read_field "$d/manifest.json" target)"
       channel="$(manifest_read_field "$d/manifest.json" channel)"
       hardware_class="$(manifest_read_field "$d/manifest.json" hardwareClass)"
    fi

    local target_col="${target:-desconhecido}"
    local channel_col="${channel:-n/a}"
    local hw_col="${hardware_class:-n/a}"

    if [[ -n "$meta" ]]; then
      printf "  %-25s %-10s %-18s %-18s %-8s %-16s ← %s\n" "$ver" "$size" "$timestamp" "$target_col" "$channel_col" "$hw_col" "$meta"
    else
      printf "    %-25s %-10s %-18s %-18s %-8s %-16s\n" "$ver" "$size" "$timestamp" "$target_col" "$channel_col" "$hw_col"
    fi
    (( count++ )) || true
  done

  [[ $count -eq 0 ]] && log_warn "Nenhuma versão encontrada."
  echo ""
  echo "  Total: $count versão(ões)"
}
