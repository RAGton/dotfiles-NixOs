#!/usr/bin/env bash
# Purpose: Criar ou reconciliar o laboratorio KVM/libvirt do RAGOS em host Linux/NixOS
# Category: dev
# Safety: destructive
# Expected environment: host Linux/NixOS com libvirt, KVM, OVMF e permissao para qemu:///system
# Requires: bash, virsh, virt-install, qemu-img
# Notes: Rede PXE dedicada sem NAT/DHCP do libvirt; DHCP/PXE vem do srv-rag

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
LIBVIRT_URI="${LIBVIRT_URI:-qemu:///system}"

NETWORK_NAME="net-ragthink"
BRIDGE_NAME="virbr-ragthink"
LAB_HOST_IP="192.168.100.1"
LAB_NETMASK="255.255.255.0"
LAB_SERVER_IP="192.168.100.2"
LAB_MTU="1500"

STORAGE_DIR="/var/lib/libvirt/images"
ISO_BASE_DIR="/srv/vm-lab/iso"

SRV_NAME="srv-rag"
SRV_VCPUS="4"
SRV_MEM_MIB="6144"
SRV_SYSTEM_DISK_SIZE_GIB="80"
SRV_DATA_DISK_SIZE_GIB="100"
SRV_SYSTEM_DISK_PATH="${STORAGE_DIR}/${SRV_NAME}-system.qcow2"
SRV_DATA_DISK_PATH="${STORAGE_DIR}/${SRV_NAME}-data.qcow2"

CLIENT_VCPUS="2"
CLIENT_MEM_MIB="4096"
CLIENT_NAMES=("tc-01" "tc-02")

SRV_LAB_MAC="52:54:00:64:10:01"
SRV_UPLINK_MAC="52:54:00:64:10:02"
TC01_MAC="52:54:00:64:10:11"
TC02_MAC="52:54:00:64:10:12"

WITH_UPLINK=0
RECREATE=0
DRY_RUN=0
ISO_PATH=""
OVMF_STATUS=""
NETWORK_STATUS=""
SRV_STATUS=""
TC01_STATUS=""
TC02_STATUS=""

usage() {
  cat <<EOF
Uso: ${SCRIPT_NAME} [opcoes]

Cria ou reconcilia o laboratorio KVM/libvirt do RAGOS:
- rede dedicada ${NETWORK_NAME} em ${LAB_HOST_IP}/24, sem NAT e sem DHCP do libvirt
- 1 VM servidor: ${SRV_NAME}
- 2 VMs cliente: ${CLIENT_NAMES[0]} e ${CLIENT_NAMES[1]}

Opcoes:
  --iso CAMINHO            ISO usada para instalar ${SRV_NAME}. Se relativo, tenta ${ISO_BASE_DIR}/CAMINHO.
  --mtu 1500|9000          MTU da rede dedicada. Default: ${LAB_MTU}
  --srv-mem MIB            RAM do servidor em MiB. Default: ${SRV_MEM_MIB}
  --client-mem MIB         RAM de cada cliente em MiB. Default: ${CLIENT_MEM_MIB}
  --storage-dir CAMINHO    Diretorio dos discos qcow2. Default: ${STORAGE_DIR}
  --network-name NOME      Nome da rede libvirt dedicada. Default: ${NETWORK_NAME}
  --bridge-name NOME       Nome da bridge da rede dedicada. Default: ${BRIDGE_NAME}
  --with-uplink            Adiciona NIC extra do ${SRV_NAME} na rede libvirt default
  --recreate               Recria VMs do laboratorio e apaga discos do ${SRV_NAME}
  --dry-run                Mostra o que seria feito sem alterar o host
  --help                   Exibe esta ajuda

Observacoes:
- DHCP/PXE dos clientes deve vir do dnsmasq do proprio ${SRV_NAME}, nao do libvirt.
- MTU 9000 e opcional e so ajuda quando bridge, host, guest e toda a pilha suportam jumbo frame.
EOF
}

log() {
  printf '[info] %s\n' "$*"
}

warn() {
  printf '[warn] %s\n' "$*" >&2
}

die() {
  printf '[error] %s\n' "$*" >&2
  exit 1
}

run_cmd() {
  if (( DRY_RUN )); then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi

  "$@"
}

require_cmd() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || die "comando obrigatorio ausente: ${cmd}"
  done
}

require_integer() {
  local label="$1"
  local value="$2"

  [[ "$value" =~ ^[0-9]+$ ]] || die "${label} deve ser inteiro: ${value}"
}

resolve_iso_path() {
  local requested="$1"

  if [[ -f "$requested" ]]; then
    printf '%s\n' "$requested"
    return 0
  fi

  if [[ "$requested" != /* ]] && [[ -f "${ISO_BASE_DIR}/${requested}" ]]; then
    printf '%s\n' "${ISO_BASE_DIR}/${requested}"
    return 0
  fi

  return 1
}

domain_exists() {
  virsh --connect "$LIBVIRT_URI" dominfo "$1" >/dev/null 2>&1
}

domain_is_running() {
  [[ "$(virsh --connect "$LIBVIRT_URI" domstate "$1" 2>/dev/null | tr '[:upper:]' '[:lower:]')" == "running" ]]
}

network_exists() {
  virsh --connect "$LIBVIRT_URI" net-info "$NETWORK_NAME" >/dev/null 2>&1
}

network_is_active() {
  [[ "$(virsh --connect "$LIBVIRT_URI" net-info "$NETWORK_NAME" 2>/dev/null | awk '/^Active:/ { print $2 }')" == "yes" ]]
}

regex_escape() {
  printf '%s' "$1" | sed -e 's/[][(){}.^$*+?|\\/]/\\&/g'
}

ensure_ovmf_support() {
  local caps loader

  caps="$(virsh --connect "$LIBVIRT_URI" domcapabilities --machine q35 --arch x86_64 2>/dev/null || true)"
  if [[ -n "$caps" ]] && grep -q '<value>efi</value>' <<<"$caps"; then
    loader="$(sed -n "s#.*<value>\\(/run/libvirt/nix-ovmf/[^<]*\\)</value>.*#\\1#p" <<<"$caps" | head -n 1)"
    if [[ -z "$loader" ]]; then
      loader="$(sed -n "s#.*<value>\\([^<]*edk2-x86_64[^<]*\\.fd\\)</value>.*#\\1#p" <<<"$caps" | head -n 1)"
    fi

    OVMF_STATUS="UEFI/OVMF detectado via libvirt${loader:+ (${loader})}"
    return 0
  fi

  local candidate
  for candidate in \
    /run/libvirt/nix-ovmf/edk2-x86_64-code.fd \
    /run/libvirt/nix-ovmf/edk2-x86_64-secure-code.fd \
    /usr/share/OVMF/OVMF_CODE.fd \
    /usr/share/edk2/ovmf/OVMF_CODE.fd; do
    if [[ -f "$candidate" ]]; then
      OVMF_STATUS="OVMF detectado em ${candidate}; confirme suporte EFI no libvirt antes de executar."
      return 0
    fi
  done

  die "OVMF/UEFI nao encontrado. Confirme libvirt com firmware EFI habilitado no host."
}

write_network_xml() {
  local xml_path="$1"
  local mtu_line=""

  if [[ "$LAB_MTU" == "9000" ]]; then
    mtu_line="  <mtu size='${LAB_MTU}'/>"
  fi

  cat >"$xml_path" <<EOF
<network>
  <name>${NETWORK_NAME}</name>
${mtu_line}
  <bridge name='${BRIDGE_NAME}' stp='on' delay='0'/>
  <ip address='${LAB_HOST_IP}' netmask='${LAB_NETMASK}'/>
</network>
EOF
}

network_is_compatible() {
  local xml="$1"
  local current_mtu=""

  grep -Fq "<bridge name='${BRIDGE_NAME}'" <<<"$xml" || return 1
  grep -Fq "<ip address='${LAB_HOST_IP}' netmask='${LAB_NETMASK}'" <<<"$xml" || return 1
  grep -Eq '<forward(\s|>)' <<<"$xml" && return 1
  grep -Eq '<dhcp(\s|>)' <<<"$xml" && return 1

  current_mtu="$(sed -n "s/.*<mtu size='\\([0-9]\\+\\)'.*/\\1/p" <<<"$xml" | head -n 1)"
  if [[ -n "$current_mtu" && "$current_mtu" != "$LAB_MTU" ]]; then
    return 1
  fi

  if [[ -z "$current_mtu" && "$LAB_MTU" == "9000" ]]; then
    return 1
  fi

  return 0
}

reconcile_network() {
  local xml_path="$1"
  local current_xml=""

  if network_exists; then
    current_xml="$(virsh --connect "$LIBVIRT_URI" net-dumpxml "$NETWORK_NAME")"
    if network_is_compatible "$current_xml"; then
      NETWORK_STATUS="rede ${NETWORK_NAME} ja esta alinhada"
    else
      log "Rede ${NETWORK_NAME} existe em estado diferente do esperado; redefinindo sem NAT e sem DHCP."
      if network_is_active; then
        run_cmd virsh --connect "$LIBVIRT_URI" net-destroy "$NETWORK_NAME"
      fi
      run_cmd virsh --connect "$LIBVIRT_URI" net-undefine "$NETWORK_NAME"
      run_cmd virsh --connect "$LIBVIRT_URI" net-define "$xml_path"
      run_cmd virsh --connect "$LIBVIRT_URI" net-start "$NETWORK_NAME"
      run_cmd virsh --connect "$LIBVIRT_URI" net-autostart "$NETWORK_NAME"
      NETWORK_STATUS="rede ${NETWORK_NAME} reconciliada"
    fi
  else
    run_cmd virsh --connect "$LIBVIRT_URI" net-define "$xml_path"
    run_cmd virsh --connect "$LIBVIRT_URI" net-start "$NETWORK_NAME"
    run_cmd virsh --connect "$LIBVIRT_URI" net-autostart "$NETWORK_NAME"
    NETWORK_STATUS="rede ${NETWORK_NAME} criada"
  fi

  if [[ "$LAB_MTU" == "9000" ]]; then
    apply_bridge_mtu
  fi
}

apply_bridge_mtu() {
  if ! command -v ip >/dev/null 2>&1; then
    warn "comando ip ausente; a bridge ${BRIDGE_NAME} pode exigir ajuste manual de MTU para ${LAB_MTU}."
    return 0
  fi

  if (( DRY_RUN )); then
    printf '[dry-run] ip link set dev %q mtu %q\n' "$BRIDGE_NAME" "$LAB_MTU"
    return 0
  fi

  if ip link show dev "$BRIDGE_NAME" >/dev/null 2>&1; then
    if ! ip link set dev "$BRIDGE_NAME" mtu "$LAB_MTU"; then
      warn "nao foi possivel aplicar MTU ${LAB_MTU} na bridge ${BRIDGE_NAME}; confirme manualmente no host."
    fi
  else
    warn "bridge ${BRIDGE_NAME} ainda nao esta visivel; confirme manualmente o MTU ${LAB_MTU} apos iniciar a rede."
  fi
}

ensure_storage_dir() {
  run_cmd sudo -n mkdir -p "$STORAGE_DIR"
}

ensure_qcow2_disk() {
  local path="$1"
  local size_gib="$2"
  local expected_bytes
  local info
  local current_bytes

  expected_bytes=$((size_gib * 1024 * 1024 * 1024))

  if [[ -f "$path" ]]; then
    # O laboratorio pode ser reconciliado com VMs em execucao; nesse caso
    # o qcow2 precisa ser aberto em modo compartilhado para leitura.
    info="$(qemu-img info -U "$path")"
    grep -Fq 'file format: qcow2' <<<"$info" || die "disco existente nao e qcow2: ${path}"
    current_bytes="$(sed -n 's/^virtual size: .* (\([0-9]\+\) bytes)$/\1/p' <<<"$info" | head -n 1)"
    [[ -n "$current_bytes" ]] || die "nao foi possivel ler o tamanho virtual do disco: ${path}"
    [[ "$current_bytes" == "$expected_bytes" ]] || die "disco existente com tamanho inesperado em ${path}; use --recreate para recriar."
    return 0
  fi

  run_cmd sudo -n qemu-img create -f qcow2 "$path" "${size_gib}G"
}

undefine_domain() {
  local name="$1"

  if ! domain_exists "$name"; then
    return 0
  fi

  if domain_is_running "$name"; then
    run_cmd virsh --connect "$LIBVIRT_URI" destroy "$name"
  fi

  if (( DRY_RUN )); then
    printf '[dry-run] virsh --connect %q undefine %q --nvram\n' "$LIBVIRT_URI" "$name"
    return 0
  fi

  if ! virsh --connect "$LIBVIRT_URI" undefine "$name" --nvram >/dev/null 2>&1; then
    virsh --connect "$LIBVIRT_URI" undefine "$name" >/dev/null
  fi
}

remove_srv_disks_if_requested() {
  if (( ! RECREATE )); then
    return 0
  fi

  run_cmd sudo -n rm -f "$SRV_SYSTEM_DISK_PATH" "$SRV_DATA_DISK_PATH"
}

check_required_pattern() {
  local xml="$1"
  local pattern="$2"
  local description="$3"
  local subject="${4:-o recurso}"

  grep -Eq "$pattern" <<<"$xml" || die "${description}; use --recreate para redefinir ${subject}."
}

validate_existing_srv_domain() {
  local xml domif

  xml="$(virsh --connect "$LIBVIRT_URI" dumpxml "$SRV_NAME")"
  check_required_pattern "$xml" "<os firmware=['\"]efi['\"]>" "${SRV_NAME} nao esta em UEFI/OVMF" "$SRV_NAME"
  if ! grep -Eq "secure=['\"]no['\"]|<feature enabled=['\"]no['\"] name=['\"]secure-boot['\"]" <<<"$xml"; then
    die "${SRV_NAME} nao fixa OVMF sem Secure Boot; use --recreate para redefinir ${SRV_NAME}."
  fi
  check_required_pattern "$xml" "<serial type=['\"]pty['\"]" "${SRV_NAME} nao tem serial pty configurado" "$SRV_NAME"
  check_required_pattern "$xml" "<console type=['\"]pty['\"]" "${SRV_NAME} nao tem console libvirt configurado" "$SRV_NAME"
  check_required_pattern "$xml" "<graphics type=['\"]spice['\"][^>]*listen=['\"]127\\.0\\.0\\.1['\"]" "${SRV_NAME} nao usa SPICE local dedicado" "$SRV_NAME"
  check_required_pattern "$xml" "<gl enable=['\"]no['\"]" "${SRV_NAME} nao fixa SPICE GL desligado" "$SRV_NAME"
  check_required_pattern "$xml" "<model type=['\"]virtio['\"]" "${SRV_NAME} nao usa video virtio no laboratorio" "$SRV_NAME"
  grep -Fq "$SRV_SYSTEM_DISK_PATH" <<<"$xml" || die "${SRV_NAME} nao referencia o disco de sistema esperado; use --recreate para redefinir ${SRV_NAME}."
  grep -Fq "$SRV_DATA_DISK_PATH" <<<"$xml" || die "${SRV_NAME} nao referencia o disco de dados esperado; use --recreate para redefinir ${SRV_NAME}."
  domif="$(virsh --connect "$LIBVIRT_URI" domiflist "$SRV_NAME")"
  awk -v net="$NETWORK_NAME" -v mac="${SRV_LAB_MAC,,}" '
    $3 == net && tolower($5) == mac { found=1 }
    END { exit found ? 0 : 1 }
  ' <<<"$domif" || die "${SRV_NAME} nao associa ${NETWORK_NAME} ao MAC ${SRV_LAB_MAC}; use --recreate para redefinir ${SRV_NAME}."

  if (( WITH_UPLINK )); then
    awk -v net="default" -v mac="${SRV_UPLINK_MAC,,}" '
      $3 == net && tolower($5) == mac { found=1 }
      END { exit found ? 0 : 1 }
    ' <<<"$domif" || die "${SRV_NAME} nao associa a rede default ao MAC ${SRV_UPLINK_MAC}; use --recreate para redefinir ${SRV_NAME}."
  fi

  if [[ -n "$ISO_PATH" ]] && ! grep -Fq "$ISO_PATH" <<<"$xml"; then
    die "${SRV_NAME} ja existe sem a ISO solicitada anexada; use --recreate para redefinir ${SRV_NAME}."
  fi
}

validate_existing_client_domain() {
  local name="$1"
  local mac="$2"
  local xml domif

  xml="$(virsh --connect "$LIBVIRT_URI" dumpxml "$name")"
  check_required_pattern "$xml" "<os firmware=['\"]efi['\"]>" "${name} nao esta em UEFI/OVMF" "$name"
  check_required_pattern "$xml" "<feature enabled=['\"]no['\"] name=['\"]secure-boot['\"]" "${name} esta com Secure Boot habilitado fora do contrato do laboratorio" "$name"
  check_required_pattern "$xml" "<boot dev=['\"]network['\"]" "${name} nao esta configurado para boot por rede" "$name"
  check_required_pattern "$xml" "<graphics type=['\"]spice['\"][^>]*listen=['\"]127\\.0\\.0\\.1['\"]" "${name} nao expõe display SPICE local para validacao grafica" "$name"
  check_required_pattern "$xml" "<video>" "${name} nao declara dispositivo de video" "$name"
  check_required_pattern "$xml" "<model type=['\"]virtio['\"]" "${name} nao usa video virtio no laboratorio" "$name"
  check_required_pattern "$xml" "<serial type=['\"]pty['\"]" "${name} nao tem serial pty configurado" "$name"
  check_required_pattern "$xml" "<console type=['\"]pty['\"]" "${name} nao tem console libvirt configurado" "$name"
  domif="$(virsh --connect "$LIBVIRT_URI" domiflist "$name")"
  awk -v net="$NETWORK_NAME" -v expected_mac="${mac,,}" '
    $3 == net && tolower($5) == expected_mac { found=1 }
    END { exit found ? 0 : 1 }
  ' <<<"$domif" || die "${name} nao associa ${NETWORK_NAME} ao MAC ${mac}; use --recreate para redefinir ${name}."
}

server_disk_arg() {
  local path="$1"
  local size_gib="$2"

  if [[ -f "$path" ]]; then
    printf 'path=%s,format=qcow2,bus=virtio' "$path"
  else
    printf 'path=%s,size=%s,format=qcow2,bus=virtio' "$path" "$size_gib"
  fi
}

define_server_domain() {
  local xml_path="$1"
  local -a cmd

  cmd=(
    virt-install
    --connect "$LIBVIRT_URI"
    --name "$SRV_NAME"
    --memory "$SRV_MEM_MIB"
    --vcpus "$SRV_VCPUS"
    --cpu host-passthrough
    --machine q35
    --import
    --boot uefi=on,firmware.feature0.name=secure-boot,firmware.feature0.enabled=no,bootmenu.enable=on,cdrom=on,hd=on
    --disk "$(server_disk_arg "$SRV_SYSTEM_DISK_PATH" "$SRV_SYSTEM_DISK_SIZE_GIB")"
    --disk "$(server_disk_arg "$SRV_DATA_DISK_PATH" "$SRV_DATA_DISK_SIZE_GIB")"
    --disk "path=${ISO_PATH},device=cdrom,bus=sata"
    --network "network=${NETWORK_NAME},model=virtio,mac=${SRV_LAB_MAC}"
    # A ISO do installer entra em menu/boot grafico por padrao, entao o servidor
    # precisa de display acessivel no virt-manager mesmo mantendo serial para
    # automacao e troubleshooting.
    --graphics "spice,listen=127.0.0.1,gl=off"
    --video virtio
    --serial pty
    --console pty,target_type=serial
    --osinfo "name=linux2024"
    --noautoconsole
    --dry-run
    --print-xml
  )

  if (( WITH_UPLINK )); then
    cmd+=(--network "network=default,model=virtio,mac=${SRV_UPLINK_MAC}")
  fi

  "${cmd[@]}" >"$xml_path"

  if (( DRY_RUN )); then
    printf '[dry-run] virsh --connect %q define %q\n' "$LIBVIRT_URI" "$xml_path"
  else
    virsh --connect "$LIBVIRT_URI" define "$xml_path" >/dev/null
  fi

  SRV_STATUS="VM ${SRV_NAME} criada"
}

define_client_domain() {
  local name="$1"
  local mac="$2"
  local xml_path="$3"
  local -a cmd

  cmd=(
    virt-install
    --connect "$LIBVIRT_URI"
    --name "$name"
    --memory "$CLIENT_MEM_MIB"
    --vcpus "$CLIENT_VCPUS"
    --cpu host-passthrough
    --machine q35
    --import
    --boot uefi=on,firmware.feature0.name=secure-boot,firmware.feature0.enabled=no,bootmenu.enable=on,network=on
    --disk none
    --network "network=${NETWORK_NAME},model=virtio,mac=${mac}"
    --graphics "spice,listen=127.0.0.1,gl=off"
    --video virtio
    --serial pty
    --console pty,target_type=serial
    --osinfo "name=linux2024"
    --noautoconsole
    --dry-run
    --print-xml
  )

  "${cmd[@]}" >"$xml_path"

  if (( DRY_RUN )); then
    printf '[dry-run] virsh --connect %q define %q\n' "$LIBVIRT_URI" "$xml_path"
  else
    virsh --connect "$LIBVIRT_URI" define "$xml_path" >/dev/null
  fi
}

ensure_server_domain() {
  local xml_path="$1"

  if domain_exists "$SRV_NAME"; then
    if (( RECREATE )); then
      log "Recriando ${SRV_NAME} e seus discos."
      undefine_domain "$SRV_NAME"
      remove_srv_disks_if_requested
    else
      validate_existing_srv_domain
      ensure_qcow2_disk "$SRV_SYSTEM_DISK_PATH" "$SRV_SYSTEM_DISK_SIZE_GIB"
      ensure_qcow2_disk "$SRV_DATA_DISK_PATH" "$SRV_DATA_DISK_SIZE_GIB"
      SRV_STATUS="VM ${SRV_NAME} ja existe e esta alinhada"
      return 0
    fi
  fi

  ensure_qcow2_disk "$SRV_SYSTEM_DISK_PATH" "$SRV_SYSTEM_DISK_SIZE_GIB"
  ensure_qcow2_disk "$SRV_DATA_DISK_PATH" "$SRV_DATA_DISK_SIZE_GIB"
  define_server_domain "$xml_path"
}

ensure_client_domain() {
  local name="$1"
  local mac="$2"
  local xml_path="$3"

  if domain_exists "$name"; then
    if (( RECREATE )); then
      log "Recriando ${name}."
      undefine_domain "$name"
    else
      validate_existing_client_domain "$name" "$mac"
      if [[ "$name" == "${CLIENT_NAMES[0]}" ]]; then
        TC01_STATUS="VM ${name} ja existe e esta alinhada"
      else
        TC02_STATUS="VM ${name} ja existe e esta alinhada"
      fi
      return 0
    fi
  fi

  define_client_domain "$name" "$mac" "$xml_path"
  if [[ "$name" == "${CLIENT_NAMES[0]}" ]]; then
    TC01_STATUS="VM ${name} criada"
  else
    TC02_STATUS="VM ${name} criada"
  fi
}

print_summary() {
  cat <<EOF

Resumo do laboratorio RAGOS
- ${NETWORK_STATUS}
- bridge: ${BRIDGE_NAME}
- host da rede PXE: ${LAB_HOST_IP}/24
- servidor planejado: ${LAB_SERVER_IP}/24
- discos do ${SRV_NAME}:
  ${SRV_SYSTEM_DISK_PATH} (${SRV_SYSTEM_DISK_SIZE_GIB}G)
  ${SRV_DATA_DISK_PATH} (${SRV_DATA_DISK_SIZE_GIB}G)
- ${SRV_STATUS}
- ${TC01_STATUS}
- ${TC02_STATUS}
- MACs definidos:
  ${SRV_NAME} lab ${SRV_LAB_MAC}
  ${SRV_NAME} uplink ${SRV_UPLINK_MAC}$(if (( ! WITH_UPLINK )); then printf ' (nao anexado)'; fi)
  ${CLIENT_NAMES[0]} ${TC01_MAC}
  ${CLIENT_NAMES[1]} ${TC02_MAC}
- firmware: ${OVMF_STATUS}

Comandos uteis
virsh start ${SRV_NAME}
virsh start ${CLIENT_NAMES[0]}
virsh start ${CLIENT_NAMES[1]}
virsh console ${SRV_NAME}
virsh console ${CLIENT_NAMES[0]}
virsh console ${CLIENT_NAMES[1]}
virsh net-dumpxml ${NETWORK_NAME}
EOF

  if [[ "$LAB_MTU" == "9000" ]]; then
    printf '%s\n' "Observacao: MTU 9000 foi solicitado para a rede interna, mas jumbo frame so ajuda com suporte ponta a ponta."
  fi
}

parse_args() {
  while (( $# > 0 )); do
    case "$1" in
      --iso)
        [[ $# -ge 2 ]] || die "--iso exige um caminho"
        ISO_PATH="$2"
        shift 2
        ;;
      --mtu)
        [[ $# -ge 2 ]] || die "--mtu exige um valor"
        LAB_MTU="$2"
        shift 2
        ;;
      --srv-mem)
        [[ $# -ge 2 ]] || die "--srv-mem exige um valor"
        SRV_MEM_MIB="$2"
        shift 2
        ;;
      --client-mem)
        [[ $# -ge 2 ]] || die "--client-mem exige um valor"
        CLIENT_MEM_MIB="$2"
        shift 2
        ;;
      --storage-dir)
        [[ $# -ge 2 ]] || die "--storage-dir exige um caminho"
        STORAGE_DIR="$2"
        SRV_SYSTEM_DISK_PATH="${STORAGE_DIR}/${SRV_NAME}-system.qcow2"
        SRV_DATA_DISK_PATH="${STORAGE_DIR}/${SRV_NAME}-data.qcow2"
        shift 2
        ;;
      --network-name)
        [[ $# -ge 2 ]] || die "--network-name exige um nome"
        NETWORK_NAME="$2"
        shift 2
        ;;
      --bridge-name)
        [[ $# -ge 2 ]] || die "--bridge-name exige um nome"
        BRIDGE_NAME="$2"
        shift 2
        ;;
      --with-uplink)
        WITH_UPLINK=1
        shift
        ;;
      --recreate)
        RECREATE=1
        shift
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        die "opcao desconhecida: $1"
        ;;
    esac
  done
}

main() {
  local net_xml
  local srv_xml
  local tc01_xml
  local tc02_xml

  parse_args "$@"

  require_cmd virsh virt-install qemu-img
  require_integer "--srv-mem" "$SRV_MEM_MIB"
  require_integer "--client-mem" "$CLIENT_MEM_MIB"

  case "$LAB_MTU" in
    1500|9000)
      ;;
    *)
      die "--mtu deve ser 1500 ou 9000"
      ;;
  esac

  if (( WITH_UPLINK )) && ! virsh --connect "$LIBVIRT_URI" net-info default >/dev/null 2>&1; then
    die "--with-uplink exige a rede libvirt default disponivel"
  fi

  if [[ -n "$ISO_PATH" ]]; then
    ISO_PATH="$(resolve_iso_path "$ISO_PATH" || true)"
    [[ -n "$ISO_PATH" ]] || die "ISO nao encontrada. Informe caminho valido ou use ${ISO_BASE_DIR}/<arquivo>."
  fi

  if (( RECREATE )) || ! domain_exists "$SRV_NAME"; then
    [[ -n "$ISO_PATH" ]] || die "a criacao/recriacao de ${SRV_NAME} exige --iso"
  fi

  ensure_ovmf_support
  ensure_storage_dir

  net_xml="$(mktemp)"
  srv_xml="$(mktemp)"
  tc01_xml="$(mktemp)"
  tc02_xml="$(mktemp)"
  trap "rm -f '$net_xml' '$srv_xml' '$tc01_xml' '$tc02_xml'" EXIT

  write_network_xml "$net_xml"
  reconcile_network "$net_xml"

  ensure_server_domain "$srv_xml"
  ensure_client_domain "${CLIENT_NAMES[0]}" "$TC01_MAC" "$tc01_xml"
  ensure_client_domain "${CLIENT_NAMES[1]}" "$TC02_MAC" "$tc02_xml"

  print_summary
}

main "$@"
