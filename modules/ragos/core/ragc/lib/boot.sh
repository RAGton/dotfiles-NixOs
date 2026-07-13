ipxe_declared_value() {
  local script_path="$1"
  local variable="$2"
  awk -v var="$variable" '$1 == "set" && $2 == var { print $3; exit }' "$script_path" 2>/dev/null
}

channel_boot_state() {
  local channel="$1"
  local pointer="current-$channel"
  local version=""
  local init=""
  local params=""

  if pointer_exists "$pointer"; then
    version="$(pointer_version "$pointer")"
    init="$(read_generation_init_path "$IMAGES_ROOT/$version")"
    params="$(read_generation_kernel_params "$IMAGES_ROOT/$version")"
  fi

  printf '%s|%s|%s\n' "$version" "$init" "$params"
}

write_channel_ipxe() {
  local script_path="$1"
  local channel="$2"
  local build_id="$3"
  local init_path="$4"
  local kernel_params="$5"
  local boot_dir="current-$channel"

  if [[ "$channel" == "rescue" ]]; then
    boot_dir="rescue"
  fi

  if [[ -n "$build_id" && -n "$init_path" ]]; then
    cat > "$script_path" <<IPXE
#!ipxe

set build_id $build_id
isset \${ip} || dhcp
echo Booting RAGOS $channel (\${build_id})...
kernel http://$SERVER_IP:$HTTP_PORT/netboot/$boot_dir/bzImage init=$init_path ip=dhcp ragos.primaryNicMac=\${net0/mac} $kernel_params
initrd http://$SERVER_IP:$HTTP_PORT/netboot/$boot_dir/initrd
boot || goto failed

:failed
echo Boot $channel falhou. Indo para shell...
shell
IPXE
  else
    cat > "$script_path" <<IPXE
#!ipxe

echo Nenhuma geracao ativa disponivel para o canal $channel.
echo Publique com: ragc switch --channel $channel
shell
IPXE
  fi
}

prepare_boot_bundle() {
  local bundle_dir="$1"
  local current_ver="$2"
  local current_init="$3"
  local rescue_ver="$4"
  local rescue_init="$5"
  local current_params=""
  local rescue_params=""
  local current_channel=""
  local generic_state=""
  local generic_ver=""
  local generic_init=""
  local generic_params=""
  local lab_state=""
  local lab_ver=""
  local lab_init=""
  local lab_params=""

  mkdir -p "$bundle_dir"

  if [[ -n "$current_ver" ]]; then
    current_params="$(read_generation_kernel_params "$IMAGES_ROOT/$current_ver")"
  fi

  if [[ -n "$rescue_ver" ]]; then
    rescue_params="$(read_generation_kernel_params "$IMAGES_ROOT/$rescue_ver")"
  fi

  if [[ -n "$current_ver" && -f "$IMAGES_ROOT/$current_ver/manifest.json" ]]; then
    current_channel="$(manifest_read_field "$IMAGES_ROOT/$current_ver/manifest.json" channel)"
  fi

  generic_state="$(channel_boot_state generic)"
  IFS='|' read -r generic_ver generic_init generic_params <<<"$generic_state"
  if [[ "$current_channel" == "generic" ]]; then
    generic_ver="$current_ver"
    generic_init="$current_init"
    generic_params="$current_params"
  fi

  lab_state="$(channel_boot_state lab)"
  IFS='|' read -r lab_ver lab_init lab_params <<<"$lab_state"
  if [[ "$current_channel" == "lab" ]]; then
    lab_ver="$current_ver"
    lab_init="$current_init"
    lab_params="$current_params"
  fi

  cat > "$bundle_dir/boot.ipxe" <<IPXE
#!ipxe

set current_build_id $current_ver
set generic_build_id ${generic_ver:-none}
set lab_build_id ${lab_ver:-none}
set rescue_build_id ${rescue_ver:-none}
isset \${ip} || dhcp
isset \${net0/mac} || goto menu
chain --replace http://$SERVER_IP:$HTTP_PORT/by-mac/\${net0/mac}.ipxe || goto menu
:menu
menu RAGOS Boot
item --gap -- =====================================
item generic Boot generic (\${generic_build_id})
item lab Boot lab (\${lab_build_id})
item current Boot current legacy (\${current_build_id})
item rescue Boot rescue (\${rescue_build_id})
item shell iPXE shell
item reboot Reboot
choose --timeout 8000 --default generic target && goto \${target}

:generic
chain --replace http://$SERVER_IP:$HTTP_PORT/generic.ipxe || goto failed

:lab
chain --replace http://$SERVER_IP:$HTTP_PORT/lab.ipxe || goto failed

:current
chain --replace http://$SERVER_IP:$HTTP_PORT/current.ipxe || goto failed

:rescue
chain --replace http://$SERVER_IP:$HTTP_PORT/rescue.ipxe || goto failed

:failed
echo Boot falhou. Indo para shell...
shell

:reboot
reboot
IPXE

  write_channel_ipxe "$bundle_dir/generic.ipxe" "generic" "$generic_ver" "$generic_init" "$generic_params"
  write_channel_ipxe "$bundle_dir/lab.ipxe" "lab" "$lab_ver" "$lab_init" "$lab_params"

  cat > "$bundle_dir/current.ipxe" <<IPXE
#!ipxe

set build_id $current_ver
isset \${ip} || dhcp
echo Booting RAGOS current (\${build_id})...
kernel http://$SERVER_IP:$HTTP_PORT/netboot/current/bzImage init=$current_init ip=dhcp ragos.primaryNicMac=\${net0/mac} $current_params
initrd http://$SERVER_IP:$HTTP_PORT/netboot/current/initrd
boot || goto failed

:failed
echo Boot falhou. Indo para shell...
shell
IPXE

  if [[ -n "$rescue_ver" && -n "$rescue_init" ]]; then
    cat > "$bundle_dir/rescue.ipxe" <<IPXE
#!ipxe

set build_id $rescue_ver
isset \${ip} || dhcp
echo Booting RAGOS rescue (\${build_id})...
kernel http://$SERVER_IP:$HTTP_PORT/netboot/rescue/bzImage init=$rescue_init ip=dhcp ragos.primaryNicMac=\${net0/mac} $rescue_params
initrd http://$SERVER_IP:$HTTP_PORT/netboot/rescue/initrd
boot || goto failed

:failed
echo Boot rescue falhou. Indo para shell...
shell
IPXE
  else
    cat > "$bundle_dir/rescue.ipxe" <<'IPXE'
#!ipxe

echo Nenhuma geracao de rescue disponivel.
shell
IPXE
  fi
}

validate_boot_bundle() {
  local bundle_dir="$1"
  local current_ver="$2"
  local rescue_ver="$3"

  [[ -f "$bundle_dir/boot.ipxe" ]] || die "Bundle de boot invalido: boot.ipxe ausente"
  [[ -f "$bundle_dir/generic.ipxe" ]] || die "Bundle de boot invalido: generic.ipxe ausente"
  [[ -f "$bundle_dir/lab.ipxe" ]] || die "Bundle de boot invalido: lab.ipxe ausente"
  [[ -f "$bundle_dir/current.ipxe" ]] || die "Bundle de boot invalido: current.ipxe ausente"
  [[ -f "$bundle_dir/rescue.ipxe" ]] || die "Bundle de boot invalido: rescue.ipxe ausente"
  [[ "$(ipxe_declared_value "$bundle_dir/boot.ipxe" current_build_id)" == "$current_ver" ]] || die "Bundle de boot invalido: boot.ipxe divergente"
  [[ "$(ipxe_declared_value "$bundle_dir/current.ipxe" build_id)" == "$current_ver" ]] || die "Bundle de boot invalido: current.ipxe divergente"

  if [[ -n "$rescue_ver" ]]; then
    [[ "$(ipxe_declared_value "$bundle_dir/boot.ipxe" rescue_build_id)" == "$rescue_ver" ]] || die "Bundle de boot invalido: rescue declarado divergente"
    [[ "$(ipxe_declared_value "$bundle_dir/rescue.ipxe" build_id)" == "$rescue_ver" ]] || die "Bundle de boot invalido: rescue.ipxe divergente"
  fi
}

promote_boot_bundle() {
  local bundle_dir="$1"
  local file

  mkdir -p "$HTTP_ROOT"

  for file in boot.ipxe generic.ipxe lab.ipxe current.ipxe rescue.ipxe; do
    local tmp="$HTTP_ROOT/.${file}.tmp.$$"
    cp "$bundle_dir/$file" "$tmp"
    mv -f "$tmp" "$HTTP_ROOT/$file"
  done
}

validate_channel_boot_coherence() {
  local channel="$1"
  local expected_ver="$2"
  local script_path="$HTTP_ROOT/$channel.ipxe"

  [[ -f "$script_path" ]] || die "Coerencia de boot quebrada: $channel.ipxe ausente"
  [[ -n "$expected_ver" ]] || return 0

  local declared
  declared="$(ipxe_declared_value "$script_path" build_id)"
  [[ "$declared" == "$expected_ver" ]] || die "Coerencia de boot quebrada: $channel.ipxe anuncia $declared, esperado $expected_ver"
}

validate_boot_coherence() {
  local current_ver="$1"
  local expected_http_manifest="$2"

  local boot_declared
  boot_declared="$(ipxe_declared_value "$HTTP_ROOT/boot.ipxe" current_build_id)"
  [[ "$boot_declared" == "$current_ver" ]] || die "Coerencia de boot quebrada: boot.ipxe anuncia $boot_declared, esperado $current_ver"

  local current_declared
  current_declared="$(ipxe_declared_value "$HTTP_ROOT/current.ipxe" build_id)"
  [[ "$current_declared" == "$current_ver" ]] || die "Coerencia de boot quebrada: current.ipxe anuncia $current_declared, esperado $current_ver"

  if [[ -n "$expected_http_manifest" ]]; then
    local http_id
    http_id="$(printf '%s\n' "$expected_http_manifest" | grep -E '"id"[[:space:]]*:' | head -n1 | cut -d'"' -f4)"
    [[ "$http_id" == "$current_ver" ]] || die "Coerencia de boot quebrada: HTTP serve $http_id, esperado $current_ver"
  fi
}

validate_rescue_coherence() {
  local rescue_ver="$1"
  [[ -n "$rescue_ver" ]] || return 0

  local rescue_declared
  rescue_declared="$(ipxe_declared_value "$HTTP_ROOT/rescue.ipxe" build_id)"
  [[ "$rescue_declared" == "$rescue_ver" ]] || die "Coerencia de rescue quebrada: rescue.ipxe anuncia $rescue_declared, esperado $rescue_ver"
}
