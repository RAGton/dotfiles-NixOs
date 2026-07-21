# =============================================================================
# Kryonix CLI: Installer & Hardware Module
# =============================================================================

kryonix_hardware_scan() {
  local json_mode=0
  if [[ "${1:-}" == "--json" ]]; then json_mode=1; fi

  if [[ "$json_mode" -eq 1 ]]; then
    kryonix-hardware-probe
  else
    blue_line "Escaneando hardware..."
    kryonix-hardware-probe | jq -C .
  fi
}

kryonix_disk_list() {
  local json_mode=0
  if [[ "${1:-}" == "--json" ]]; then json_mode=1; fi

  if [[ "$json_mode" -eq 1 ]]; then
    lsblk -J -o NAME,MODEL,SIZE,TYPE,MOUNTPOINT,FSTYPE
  else
    blue_line "Discos detectados:"
    lsblk -o NAME,MODEL,SIZE,TYPE,MOUNTPOINT,FSTYPE
  fi
}

kryonix_disk_plan() {
  # Fase 1 e sempre dry-run
  blue_line "Gerando plano de instalacao (DRY-RUN)..."
  kryonix-hardware-probe | kryonix-disk-planner
}

kryonix_install() {
  local sub="${1:-help}"
  shift || true

  case "$sub" in
    server)
      blue_line "Iniciando servidor do instalador (Axum)..."
      kryxd
      ;;
    gui|tui)
      blue_line "Interface $sub ainda nao implementada na Fase 1."
      printf "Dica: Use 'kryonix install server' e acesse a porta 3000.\n"
      ;;
    help|--help|-h)
      print_subcommand_help "install"
      ;;
    *)
      printf "Subcomando de instalacao desconhecido: %s\n" "$sub"
      exit 1
      ;;
  esac
}
