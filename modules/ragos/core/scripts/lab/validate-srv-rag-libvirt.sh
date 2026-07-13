#!/usr/bin/env bash
# Purpose: Validar o contrato Day-0 de reinstalacao limpa do srv-rag em KVM/libvirt
# Category: lab
# Safety: destructive
# Expected environment: host Linux/NixOS com libvirt, KVM, Nix e acesso a qemu:///system
# Requires: bash, virsh, nix

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
LIBVIRT_URI="${LIBVIRT_URI:-qemu:///system}"
LAB_CREATE_SCRIPT="${LAB_CREATE_SCRIPT:-$REPO_ROOT/scripts/dev/create-kvm-lab.sh}"
DOMAIN_NAME="${DOMAIN_NAME:-srv-rag}"
LAB_NETWORK_NAME="${LAB_NETWORK_NAME:-net-ragthink}"
LAB_BRIDGE_NAME="${LAB_BRIDGE_NAME:-virbr-ragthink}"
LAB_HOST_IP="${LAB_HOST_IP:-192.168.100.1}"
LAB_SERVER_IP="${LAB_SERVER_IP:-192.168.100.2}"
LAB_SERVER_CIDR="${LAB_SERVER_CIDR:-192.168.100.2/24}"
LAB_GW_IP="${LAB_GW_IP:-192.168.100.1}"
LAB_SRV_MEM_MIB="${LAB_SRV_MEM_MIB:-6144}"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-Ragos!2026Think}"
LIVE_USER="${LIVE_USER:-ragos}"
LIVE_PASSWORD="${LIVE_PASSWORD:-ragos}"
DEFAULT_HTTP_PORT="${DEFAULT_HTTP_PORT:-8080}"
DEFAULT_MGMT_MAC="${DEFAULT_MGMT_MAC:-52:54:00:64:10:01}"
DEFAULT_WAN_MAC="${DEFAULT_WAN_MAC:-52:54:00:64:10:02}"
DEFAULT_CLIENT_ONE_MAC="${DEFAULT_CLIENT_ONE_MAC:-52:54:00:64:10:11}"
DEFAULT_CLIENT_TWO_MAC="${DEFAULT_CLIENT_TWO_MAC:-52:54:00:64:10:12}"
LAB_CLIENT_ONE_NAME="${LAB_CLIENT_ONE_NAME:-tc-01}"
LAB_CLIENT_TWO_NAME="${LAB_CLIENT_TWO_NAME:-tc-02}"
DEFAULT_UI_OCR_TOKEN_1="${DEFAULT_UI_OCR_TOKEN_1:-RAGOS}"
DEFAULT_UI_OCR_TOKEN_2="${DEFAULT_UI_OCR_TOKEN_2:-Installer}"
DEFAULT_UI_OCR_TOKEN_3="${DEFAULT_UI_OCR_TOKEN_3:-Instalador}"
DEFAULT_UI_OCR_TOKEN_4="${DEFAULT_UI_OCR_TOKEN_4:-Instalacao}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-$REPO_ROOT/.lab-validation/$(date +%Y%m%d-%H%M%S)}"
LOCK_FILE="${LOCK_FILE:-/tmp/ragos-validate-srv-rag.lock}"
ISO_PATH="${ISO_PATH:-}"
BUILD_ISO=0
WITH_UPLINK=1
RECREATE=1
ALLOW_DEGRADED=0
UI_TIMEOUT_SECONDS="${UI_TIMEOUT_SECONDS:-1200}"
INSTALL_TIMEOUT_SECONDS="${INSTALL_TIMEOUT_SECONDS:-10800}"
BOOT_TIMEOUT_SECONDS="${BOOT_TIMEOUT_SECONDS:-1800}"
SSH_TIMEOUT_SECONDS="${SSH_TIMEOUT_SECONDS:-1800}"
INSTALL_POLL_INTERVAL_SECONDS="${INSTALL_POLL_INTERVAL_SECONDS:-10}"

usage() {
  cat <<EOF
Uso: ${SCRIPT_NAME} [opcoes]

Valida a cadeia completa do srv-rag em libvirt como aceite destrutivo de Day-0:
- build opcional da ISO
- recriacao do lab via create-kvm-lab.sh
- prova visual da UI na live ISO
- instalacao unattended via console serial
- eject da ISO e reboot do disco
- prova do primeiro boot e servicos por SSH

Opcoes:
  --iso CAMINHO           Usa uma ISO especifica.
  --build-iso             Gera a ISO do flake antes de validar.
  --no-recreate           Nao recria a VM; valida o dominio existente.
  --with-uplink           Forca a passagem de --with-uplink ao create-kvm-lab.sh. Default: ligado.
  --no-uplink             Nao passa --with-uplink ao create-kvm-lab.sh.
  --srv-mem MIB           Forca a RAM do srv-rag durante a recriacao. Default: ${LAB_SRV_MEM_MIB}
  --allow-degraded        Aceita systemd degradado se os servicos criticos estiverem ok.
  --artifacts-dir DIR     Diretoria para logs, screenshots e dumps.
  --lock-file CAMINHO     Lock de exclusao mutua para evitar validacoes concorrentes no mesmo srv-rag.
  --ui-timeout SEC        Timeout para a prova visual da UI. Default: ${UI_TIMEOUT_SECONDS}
  --install-timeout SEC   Timeout para a instalacao unattended. Default: ${INSTALL_TIMEOUT_SECONDS}
  --boot-timeout SEC      Timeout para o primeiro boot apos o reboot. Default: ${BOOT_TIMEOUT_SECONDS}
  --ssh-timeout SEC       Timeout por tentativa SSH. Default: ${SSH_TIMEOUT_SECONDS}
  --help                  Mostra esta ajuda.
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
  "$@"
}

acquire_run_lock() {
  exec 9>"$LOCK_FILE"
  if ! flock -n 9; then
    die "Ja existe outra validacao ativa para ${DOMAIN_NAME}. Lock ocupado em ${LOCK_FILE}"
  fi
}

with_expect() {
  /run/current-system/sw/bin/nix \
    --extra-experimental-features nix-command \
    --extra-experimental-features flakes \
    shell nixpkgs#expect -c "$@"
}

with_ocr_tools() {
  /run/current-system/sw/bin/nix \
    --extra-experimental-features nix-command \
    --extra-experimental-features flakes \
    shell nixpkgs#imagemagick nixpkgs#tesseract -c "$@"
}

with_ssh_tools() {
  /run/current-system/sw/bin/nix \
    --extra-experimental-features nix-command \
    --extra-experimental-features flakes \
    shell nixpkgs#sshpass nixpkgs#openssh -c "$@"
}

with_live_ssh() {
  local guest_ip="$1"
  shift || true

  with_ssh_tools sshpass -p "$LIVE_PASSWORD" ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=10 \
    "${LIVE_USER}@${guest_ip}" \
    "$@"
}

domain_exists() {
  virsh --connect "$LIBVIRT_URI" dominfo "$DOMAIN_NAME" >/dev/null 2>&1
}

domain_is_running() {
  [[ "$(virsh --connect "$LIBVIRT_URI" domstate "$DOMAIN_NAME" 2>/dev/null | tr '[:upper:]' '[:lower:]')" == "running" ]]
}

extract_first_match() {
  local pattern="$1"
  local text="$2"
  grep -Eo "$pattern" <<<"$text" | head -n 1 || true
}

resolve_iso_path() {
  local candidate
  local iso_candidates=(
    "$ISO_PATH"
    "$REPO_ROOT/result-iso/iso/ragos-installer.iso"
    "$REPO_ROOT/result/iso/ragos-installer.iso"
  )

  for candidate in "${iso_candidates[@]}"; do
    [[ -n "$candidate" ]] || continue
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

build_iso() {
  log "Construindo ISO do instalador"
  (cd "$REPO_ROOT" && \
    /run/current-system/sw/bin/nix \
      --extra-experimental-features nix-command \
      --extra-experimental-features flakes \
      build "path:$REPO_ROOT#ragos-iso" -L --out-link result-iso --cores 4 --max-jobs 1)
}

validate_lab_binary() {
  [[ -x "$LAB_CREATE_SCRIPT" ]] || die "Script de laboratorio ausente ou nao executavel: $LAB_CREATE_SCRIPT"
}

force_undefine_domain() {
  local name="$1"

  if ! virsh --connect "$LIBVIRT_URI" dominfo "$name" >/dev/null 2>&1; then
    return 0
  fi

  if [[ "$(virsh --connect "$LIBVIRT_URI" domstate "$name" 2>/dev/null | tr '[:upper:]' '[:lower:]')" == "running" ]]; then
    virsh --connect "$LIBVIRT_URI" destroy "$name" >/dev/null 2>&1 || true
  fi

  virsh --connect "$LIBVIRT_URI" undefine "$name" --nvram --managed-save --snapshots-metadata --checkpoints-metadata >/dev/null 2>&1 \
    || virsh --connect "$LIBVIRT_URI" undefine "$name" --nvram >/dev/null 2>&1 \
    || virsh --connect "$LIBVIRT_URI" undefine "$name" >/dev/null 2>&1 \
    || true

  if virsh --connect "$LIBVIRT_URI" dominfo "$name" >/dev/null 2>&1; then
    die "dominio ${name} continuou registrado no libvirt apos a limpeza forcada"
  fi
}

preclean_lab_domains() {
  log "Limpando dominios do laboratorio antes da recriacao"
  force_undefine_domain "$DOMAIN_NAME"
  force_undefine_domain "$LAB_CLIENT_ONE_NAME"
  force_undefine_domain "$LAB_CLIENT_TWO_NAME"
}

recreate_lab() {
  local iso_path="$1"
  local create_args=(bash "$LAB_CREATE_SCRIPT" --iso "$iso_path" --srv-mem "$LAB_SRV_MEM_MIB")

  if (( WITH_UPLINK )); then
    create_args+=(--with-uplink)
  fi
  if (( RECREATE )); then
    preclean_lab_domains
    create_args+=(--recreate)
  fi

  log "Recriando o laboratorio srv-rag com ISO ${iso_path}"
  "${create_args[@]}"
}

dump_domain_state() {
  local suffix="${1:-state}"
  mkdir -p "$ARTIFACTS_DIR"
  virsh --connect "$LIBVIRT_URI" dominfo "$DOMAIN_NAME" >"$ARTIFACTS_DIR/${suffix}.dominfo.txt" 2>&1 || true
  virsh --connect "$LIBVIRT_URI" domiflist "$DOMAIN_NAME" >"$ARTIFACTS_DIR/${suffix}.domiflist.txt" 2>&1 || true
  virsh --connect "$LIBVIRT_URI" dumpxml "$DOMAIN_NAME" >"$ARTIFACTS_DIR/${suffix}.xml" 2>&1 || true
}

get_domain_xml() {
  virsh --connect "$LIBVIRT_URI" dumpxml "$DOMAIN_NAME"
}

get_serial_path() {
  local xml serial_path
  xml="$(get_domain_xml)"
  serial_path="$(sed -n "s#.*<source path='\([^']*\)'.*#\1#p" <<<"$xml" | head -n 1)"
  if [[ -z "$serial_path" ]]; then
    serial_path="pty-pending"
    warn "Nao foi possivel detectar o PTY serial do dominio ${DOMAIN_NAME} antes da inicializacao; seguindo com fallback"
  fi
  printf '%s\n' "$serial_path"
}

assert_domain_contract() {
  local xml net_xml video_type loader_line graphics_line serial_line console_line
  xml="$(get_domain_xml)"
  net_xml="$(virsh --connect "$LIBVIRT_URI" net-dumpxml "$LAB_NETWORK_NAME")"

  grep -Fq "<name>${DOMAIN_NAME}</name>" <<<"$xml" || die "Domino inesperado: ${DOMAIN_NAME}"
  grep -Fq "<source network='${LAB_NETWORK_NAME}'" <<<"$xml" || die "Rede dedicada ${LAB_NETWORK_NAME} ausente no dominio"
  grep -Fq "<bridge name='${LAB_BRIDGE_NAME}'" <<<"$net_xml" || die "Bridge da rede nao confere com ${LAB_BRIDGE_NAME}"
  grep -Fq "<mac address='${DEFAULT_MGMT_MAC}'" <<<"$xml" || die "MAC da interface de gerenciamento nao confere"
  grep -Fq "<mac address='${DEFAULT_WAN_MAC}'" <<<"$xml" || die "MAC da interface WAN nao confere"
  grep -Fq "<serial type='pty'" <<<"$xml" || die "Serial pty ausente"
  grep -Fq "<console type='pty'" <<<"$xml" || die "Console pty ausente"
  grep -Fq "<graphics type='spice'" <<<"$xml" || die "Graphics SPICE ausente"

  video_type="$(
    sed -n "/<video>/,/<\/video>/p" <<<"$xml" \
      | sed -n "s#.*<model type='\\([^']*\\)'.*#\\1#p" \
      | head -n 1
  )"
  [[ "$video_type" == "virtio-vga" || "$video_type" == "virtio" ]] \
    || die "Contrato grafico invalido: video=${video_type:-desconhecido}, esperado virtio/virtio-vga"

  loader_line="$(grep -oE "<loader[^>]*>[^<]+</loader>" <<<"$xml" | head -n 1)"
  [[ -n "$loader_line" ]] || die "Loader UEFI ausente no XML"
  grep -Fq "<feature enabled='no' name='secure-boot'/>" <<<"$xml" || \
    grep -Fq "<feature enabled='no' name='secure-boot'>" <<<"$xml" || \
    die "Secure Boot ainda ativo no XML"
  grep -Fq "edk2-x86_64-code.fd" <<<"$loader_line" || die "XML nao aponta para o firmware OVMF nao seguro"

  graphics_line="$(grep -oE "<graphics[^>]+>" <<<"$xml" | head -n 1)"
  [[ -n "$graphics_line" ]] || die "Graphics libvirt ausente"
  grep -Fq "<gl enable='no'" <<<"$xml" || die "GL do SPICE ainda esta habilitado no contrato do dominio"

  serial_line="$(grep -oE "<serial type='pty'" <<<"$xml" | head -n 1)"
  console_line="$(grep -oE "<console type='pty'" <<<"$xml" | head -n 1)"
  [[ -n "$serial_line" && -n "$console_line" ]] || die "Console/serial do dominio nao estao no contrato"
}

wait_for_prompt() {
  local prompt_log="$1"
  local timeout="$2"
  local serial_path="$3"

  with_expect expect <<EOF
set timeout ${timeout}
log_user 1
log_file -noappend "$prompt_log"
spawn virsh --connect "$LIBVIRT_URI" console "$DOMAIN_NAME"
expect {
  -re {Connected to domain} {}
  timeout { puts stderr "timeout conectando ao console serial de ${DOMAIN_NAME}"; exit 1 }
}
sleep 2
send -- "\r"
expect {
  -re {[#\$] $} {}
  timeout { puts stderr "nao foi possivel detectar prompt de shell no serial ${serial_path}"; exit 1 }
}
EOF
}

run_guest_script() {
  local payload_file="$1"
  local console_log="$2"
  local timeout="$3"
  local serial_path="$4"
  local completion_marker="$5"

  with_expect expect <<EOF
set timeout ${timeout}
log_user 1
log_file -noappend "$console_log"
spawn virsh --connect "$LIBVIRT_URI" console "$DOMAIN_NAME"
expect {
  -re {Connected to domain} {}
  timeout { puts stderr "timeout conectando ao console serial de ${DOMAIN_NAME}"; exit 1 }
}
sleep 2
send -- "\r"
expect {
  -re {[#\$] $} {}
  timeout { puts stderr "nao foi possivel detectar prompt de shell no serial ${serial_path}"; exit 1 }
}
set fh [open "$payload_file" r]
set script [read \$fh]
close \$fh
send -- "\$script\r"
expect {
  -re {${completion_marker}} {}
  timeout { puts stderr "timeout aguardando conclusao da instalacao unattended"; exit 1 }
}
sleep 2
send -- "exit\r"
expect eof
EOF
}

take_screenshot() {
  local screenshot_path="$1"
  rm -f "$screenshot_path"
  virsh --connect "$LIBVIRT_URI" screenshot "$DOMAIN_NAME" "$screenshot_path" >/dev/null 2>&1
  [[ -s "$screenshot_path" ]] || die "Screenshot do live system nao foi materializado: $screenshot_path"
}

ocr_screenshot() {
  local screenshot_path="$1"
  local ocr_path="$2"

  with_ocr_tools bash -lc '
    screenshot_path="$1"
    ocr_path="$2"
    tesseract "$screenshot_path" stdout >"$ocr_path.tmp" 2>/dev/null || true
    tr -d "\f" <"$ocr_path.tmp" >"$ocr_path"
    rm -f "$ocr_path.tmp"
  ' _ "$screenshot_path" "$ocr_path"
}

assert_live_ui_visible() {
  local screenshot_path="$1"
  local ocr_path="$2"
  local ocr_text

  take_screenshot "$screenshot_path"
  ocr_screenshot "$screenshot_path" "$ocr_path"
  ocr_text="$(tr '[:upper:]' '[:lower:]' <"$ocr_path" | tr -s '[:space:]' ' ')"

  if ! grep -Eq "(ragos|installer|instalador|instalacao)" <<<"$ocr_text"; then
    warn "OCR do screenshot nao encontrou texto esperado"
    warn "OCR bruto:"
    warn "$(cat "$ocr_path")"
    die "A UI live nao ficou visivel no screenshot do libvirt"
  fi
}

build_install_payload() {
  local payload_file="$1"

  mkdir -p "$(dirname "$payload_file")"
  cat >"$payload_file" <<EOF
set -euo pipefail

find_iface_by_mac() {
  local wanted_mac="\$1"
  ip -o link | awk -F': ' -v wanted="\${wanted_mac,,}" '
    {
      iface = \$2
      line = tolower(\$0)
      if (line ~ ("link/ether " wanted " ")) {
        print iface
        exit
      }
    }
  '
}

MGMT_IFACE="\$(find_iface_by_mac "${DEFAULT_MGMT_MAC}")"
WAN_IFACE="\$(find_iface_by_mac "${DEFAULT_WAN_MAC}")"

[[ -n "\$MGMT_IFACE" ]] || {
  echo "ERRO: interface de gerenciamento nao encontrada para MAC ${DEFAULT_MGMT_MAC}" >&2
  exit 1
}

export RAGOS_SERVER_IP=${LAB_SERVER_IP}
export RAGOS_HTTP_PORT=${DEFAULT_HTTP_PORT}
export RAGOS_HOSTNAME=srv-rag
export RAGOS_TIMEZONE=America/Cuiaba
export RAGOS_LOCALE=pt_BR.UTF-8
export RAGOS_KEYMAP=br-abnt2
export RAGOS_MGMT_IFACE="\$MGMT_IFACE"
export RAGOS_MGMT_PREFIX=24
export RAGOS_MGMT_GATEWAY=${LAB_GW_IP}
export RAGOS_MGMT_DNS=1.1.1.1,8.8.8.8
export RAGOS_WAN_IFACE="\$WAN_IFACE"
export RAGOS_WAN_MODE=dhcp
export RAGOS_ADMIN_USER=${ADMIN_USER}
export RAGOS_ADMIN_UID=1000
export RAGOS_ADMIN_EMAIL=admin@example.local
export RAGOS_ADMIN_PASSWORD=${ADMIN_PASSWORD}
export RAGOS_DISK_MODE=one
export RAGOS_DISK_PROFILE=single
export RAGOS_SYS_DISK=/dev/vda
export RAGOS_ROOT_FS=btrfs
export RAGOS_DATA_FS=btrfs
export RAGOS_INSTALL_LOG_FILE=/tmp/ragos-install.log
export RAGOS_I_UNDERSTAND_THIS_WIPES_DISKS=YES

sudo mkdir -p /opt
sudo ln -sfn /iso/opt/ragos-src /opt/ragos-src

sudo -E ragos-install preflight-unattended
sudo -E ragos-install unattended

echo __RAGOS_INSTALL_DONE__
EOF
  chmod 0644 "$payload_file"
}

build_live_probe_payload() {
  local payload_file="$1"

  mkdir -p "$(dirname "$payload_file")"
  cat >"$payload_file" <<'EOF'
set -euo pipefail
systemctl is-active ragos-installer-ui.service
systemctl is-active display-manager.service
curl -fsS http://127.0.0.1:8000/api/v1/status >/dev/null
pgrep -af chromium >/dev/null
echo __RAGOS_LIVE_UI_PROBE_DONE__
EOF
  chmod 0644 "$payload_file"
}

guest_backend_ips() {
  virsh --connect "$LIBVIRT_URI" domifaddr "$DOMAIN_NAME" --source lease 2>/dev/null \
    | awk '/ipv4/ { print $4 }' \
    | sed 's#/.*##' \
    | awk 'NF && !seen[$0]++ { print $0 }'
}

wait_for_guest_backend() {
  local timeout="$1"
  local deadline="$((SECONDS + timeout))"
  local guest_ip status_url
  local -a guest_ips=()

  while (( SECONDS < deadline )); do
    if ! domain_is_running; then
      sleep 2
      continue
    fi

    mapfile -t guest_ips < <(guest_backend_ips || true)
    for guest_ip in "${guest_ips[@]}"; do
      status_url="http://${guest_ip}:8000/api/v1/status"
      if curl -fsS --max-time 3 "$status_url" >/dev/null 2>&1; then
        printf '%s\n' "$guest_ip"
        return 0
      fi
    done

    sleep 5
  done

  return 1
}

fetch_live_install_state_json() {
  local guest_ip="$1"

  with_live_ssh "$guest_ip" \
    "sudo -n cat /run/ragos-installer/install-state.json 2>/dev/null || true" \
    2>/dev/null || true
}

fetch_live_install_log_tail() {
  local guest_ip="$1"

  with_live_ssh "$guest_ip" \
    "sudo -n tail -n 40 /run/ragos-installer/install.log 2>/dev/null || true" \
    2>/dev/null || true
}

fetch_guest_disks() {
  local guest_ip="$1"

  curl -fsS --max-time 10 "http://${guest_ip}:8000/api/v1/disks"
}

json_has_install_signal() {
  local payload="${1:-}"

  [[ -n "$payload" ]] || return 1
  jq -e '
    type == "object" and (
      (.running // false) or
      (.exitCode != null) or
      (.havePlan // false) or
      (.currentPhase != null) or
      (.lastLogLine != null)
    )
  ' >/dev/null 2>&1 <<<"$payload"
}

append_install_poll_snapshot() {
  local state_log="$1"
  local source="$2"
  local api_status_json="${3:-}"
  local live_state_json="${4:-}"
  local live_log_tail="${5:-}"

  {
    printf '[%s] source=%s\n' "$(date -Is)" "$source"
    printf 'api=%s\n' "$(jq -c '.' <<<"${api_status_json:-{}}" 2>/dev/null || printf '{}')"
    printf 'live=%s\n' "$(jq -c '.' <<<"${live_state_json:-{}}" 2>/dev/null || printf '{}')"
    if [[ -n "$live_log_tail" ]]; then
      printf '%s\n' "$live_log_tail" | tail -n 8 | sed 's/^/log: /'
    fi
    printf '\n'
  } >>"$state_log"
}

domain_system_disk_virtual_size_bytes() {
  local xml disk_target

  xml="$(get_domain_xml)"
  disk_target="$(
    python3 - <<'PY' "$xml"
import re
import sys

xml = sys.argv[1]
blocks = re.findall(r"<disk type='file' device='disk'>(.*?)</disk>", xml, re.S)
for block in blocks:
    if "boot order='1'" in block or "target dev='vda'" in block:
        match = re.search(r"<target dev='([^']+)'", block)
        if match:
            print(match.group(1))
            raise SystemExit(0)
raise SystemExit(1)
PY
  )" || die "nao foi possivel localizar o target do disco primario do dominio ${DOMAIN_NAME} no XML"

  virsh --connect "$LIBVIRT_URI" domblkinfo "$DOMAIN_NAME" "$disk_target" 2>/dev/null \
    | awk '/Capacity:/ { print $2; exit }'
}

resolve_guest_network_ifaces() {
  local netifs_json="$1"
  local mgmt_iface wan_iface

  mgmt_iface="$(
    jq -r --arg mac "$DEFAULT_MGMT_MAC" '
      .interfaces[]
      | select((.macAddress // "") | ascii_downcase == ($mac | ascii_downcase))
      | .name
    ' <<<"$netifs_json" | head -n 1
  )"
  wan_iface="$(
    jq -r --arg mac "$DEFAULT_WAN_MAC" '
      .interfaces[]
      | select((.macAddress // "") | ascii_downcase == ($mac | ascii_downcase))
      | .name
    ' <<<"$netifs_json" | head -n 1
  )"

  [[ -n "$mgmt_iface" ]] || die "nao foi possivel descobrir a interface de gerenciamento via MAC ${DEFAULT_MGMT_MAC}"
  [[ -n "$wan_iface" ]] || die "nao foi possivel descobrir a interface WAN via MAC ${DEFAULT_WAN_MAC}"

  jq -n --arg mgmt "$mgmt_iface" --arg wan "$wan_iface" '{
    mgmtIface: $mgmt,
    wanIface: $wan
  }'
}

resolve_guest_install_disk() {
  local disks_json="$1"
  local expected_size sys_disk

  expected_size="$(domain_system_disk_virtual_size_bytes)"
  [[ -n "$expected_size" && "$expected_size" =~ ^[0-9]+$ ]] \
    || die "nao foi possivel determinar o tamanho virtual do disco primario do dominio"

  sys_disk="$(
    jq -r --argjson expected_size "$expected_size" '
      [
        .disks[]
        | select(.diskType == "disk")
        | select(.path | startswith("/dev/"))
        | select((.readOnly // false) | not)
        | select((.removable // false) | not)
        | select((.hotplug // false) | not)
        | select(.sizeBytes == $expected_size)
      ]
      | if length == 1 then .[0].path else empty end
    ' <<<"$disks_json"
  )"

  [[ -n "$sys_disk" ]] || die "nao foi possivel resolver unicamente o disco do sistema via /api/v1/disks"
  printf '%s\n' "$sys_disk"
}

build_backend_install_payload() {
  local payload_dir="$1"
  local netifs_json="$2"
  local disks_json="$3"
  local iface_resolution guest_mgmt_iface guest_wan_iface sys_disk
  local payload_file="$payload_dir/install-plan.json"
  local secrets_file="$payload_dir/install-secrets.json"

  iface_resolution="$(resolve_guest_network_ifaces "$netifs_json")"
  guest_mgmt_iface="$(jq -r '.mgmtIface' <<<"$iface_resolution")"
  guest_wan_iface="$(jq -r '.wanIface' <<<"$iface_resolution")"
  sys_disk="$(resolve_guest_install_disk "$disks_json")"

  [[ -n "$guest_mgmt_iface" ]] || die "nao foi possivel descobrir a interface de gerenciamento do guest via API"
  [[ -n "$guest_wan_iface" ]] || die "nao foi possivel descobrir a interface WAN do guest via API"
  [[ -n "$sys_disk" ]] || die "nao foi possivel descobrir o disco do sistema do guest via API"

  cat >"$payload_file" <<EOF
{
  "version": 1,
  "disk": {
    "mode": "one",
    "profile": "single",
    "selectedDisks": ["${sys_disk}"],
    "luksEnabled": false,
    "sysDisk": "${sys_disk}",
    "rootFs": "btrfs",
    "dataFs": "btrfs"
  },
  "network": {
    "hostname": "srv-rag",
    "interface": "${guest_mgmt_iface}",
    "serverIp": "${LAB_SERVER_IP}",
    "prefixLength": 24,
    "gateway": "${LAB_GW_IP}",
    "dns": ["1.1.1.1", "8.8.8.8"],
    "httpPort": ${DEFAULT_HTTP_PORT},
    "wan": {
      "interface": "${guest_wan_iface}",
      "mode": "dhcp",
      "dns": []
    }
  },
  "locale": {
    "country": "BR",
    "timezone": "America/Cuiaba",
    "locale": "pt_BR.UTF-8",
    "keymap": "br-abnt2"
  },
  "admin": {
    "user": "${ADMIN_USER}",
    "uid": 1000,
    "email": "admin@example.local",
    "authorizedKeys": []
  }
}
EOF

  cat >"$secrets_file" <<EOF
{
  "adminPassword": "${ADMIN_PASSWORD}",
  "adminPasswordConfirm": "${ADMIN_PASSWORD}"
}
EOF

  chmod 0644 "$payload_file" "$secrets_file"
  printf '%s\n%s\n' "$payload_file" "$secrets_file"
}

start_install_via_backend_api() {
  local guest_ip="$1"
  local payload_file="$2"
  local secrets_file="$3"
  local base_url="http://${guest_ip}:8000"
  local plan_response install_response
  local combined_payload

  combined_payload="$(
    jq -n \
      --slurpfile plan "$payload_file" \
      --slurpfile secrets "$secrets_file" \
      '{ plan: $plan[0], secrets: $secrets[0] }'
  )"
  plan_response="$(
    curl -fsS --max-time 10 \
      -H 'content-type: application/json' \
      -X POST \
      --data "$combined_payload" \
      "${base_url}/api/v1/plan"
  )"
  install_response="$(
    curl -fsS --max-time 10 \
      -H 'content-type: application/json' \
      -X POST \
      --data '{"confirmWipe":true}' \
      "${base_url}/api/v1/install"
  )"

  printf '%s\n%s\n' "$plan_response" "$install_response"
}

wait_for_install_completion() {
  local guest_ip="$1"
  local timeout="$2"
  local state_log="$3"
  local deadline="$((SECONDS + timeout))"
  local status_url="http://${guest_ip}:8000/api/v1/status"
  local api_status_json live_state_json live_log_tail effective_status effective_source

  : >"$state_log"

  while (( SECONDS < deadline )); do
    if ! domain_is_running; then
      printf '[%s] domain-state=not-running\n\n' "$(date -Is)" >>"$state_log"
      sleep 2
      continue
    fi

    api_status_json="$(curl -fsS --max-time 5 "$status_url" 2>/dev/null || true)"
    live_state_json="$(fetch_live_install_state_json "$guest_ip")"
    live_log_tail="$(fetch_live_install_log_tail "$guest_ip")"
    effective_status='{}'
    effective_source='none'

    if json_has_install_signal "$api_status_json"; then
      effective_status="$api_status_json"
      effective_source='api'
    fi

    if json_has_install_signal "$live_state_json"; then
      effective_status="$live_state_json"
      effective_source='live'
    fi

    append_install_poll_snapshot "$state_log" "$effective_source" "$api_status_json" "$live_state_json" "$live_log_tail"

    if jq -e '.running == false and (.exitCode == 0)' <<<"$effective_status" >/dev/null 2>&1; then
      printf '%s\n' "$effective_status"
      return 0
    fi

    if jq -e '.running == false and (.exitCode != null) and (.exitCode != 0)' <<<"$effective_status" >/dev/null 2>&1; then
      printf '%s\n' "$effective_status"
      return 1
    fi

    sleep "$INSTALL_POLL_INTERVAL_SECONDS"
  done

  return 1
}

validate_after_install() {
  local ssh_log="$1"
  local boot_state_log="$2"

  if ! with_ssh_tools sshpass -p "$ADMIN_PASSWORD" ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=10 \
    "${ADMIN_USER}@${LAB_SERVER_IP}" \
    "sudo -n env ALLOW_DEGRADED=${ALLOW_DEGRADED} bash -s" \
    >"$ssh_log" 2>&1 <<'REMOTE'
set -euo pipefail

state=""
for _attempt in $(seq 1 60); do
  state="$(systemctl is-system-running || true)"
  case "$state" in
    starting|initializing)
      sleep 5
      ;;
    *)
      break
      ;;
  esac
done

case "$state" in
  running)
    ;;
  degraded)
    if [[ "${ALLOW_DEGRADED:-0}" != "1" ]]; then
      echo "systemd state degraded" >&2
      exit 1
    fi
    ;;
  *)
    echo "Unexpected systemd state: $state" >&2
    exit 1
    ;;
esac

if systemctl is-active --quiet emergency.target || systemctl is-active --quiet rescue.target; then
  echo "systemd entered emergency or rescue target" >&2
  exit 1
fi

hostname
failed_units="$(systemctl --failed --plain --no-legend)"
if [[ -n "$failed_units" ]]; then
  if [[ "${ALLOW_DEGRADED:-0}" != "1" ]]; then
    printf '%s\n' "$failed_units" >&2
    exit 1
  fi
  if grep -Eq '(^| )(sshd|nginx|dnsmasq|nfs-server)\.service( |$)' <<<"$failed_units"; then
    printf '%s\n' "$failed_units" >&2
    exit 1
  fi
fi
systemctl is-active sshd nginx dnsmasq nfs-server
findmnt /boot
findmnt /nix
findmnt /srv
findmnt /srv/data/home
findmnt /srv/data/images
findmnt /srv/data/snapshots
systemctl is-active boot.mount nix.mount srv.mount srv-data-home.mount srv-data-images.mount srv-data-snapshots.mount
test -f /boot/grub/grub.cfg
test -f /boot/EFI/BOOT/BOOTX64.EFI
if { find /boot/loader -mindepth 1 -maxdepth 2 -print -quit 2>/dev/null || true; } | grep -q .; then
  echo "systemd-boot artifacts still present under /boot/loader" >&2
  exit 1
fi
params_target="$(readlink -f /etc/ragos/server/runtime/params.nix)"
hw_target="$(readlink -f /etc/ragos/server/runtime/hardware-configuration.nix)"
test "$params_target" = /var/lib/ragos/runtime/params.nix
test "$hw_target" = /var/lib/ragos/runtime/hardware-configuration.nix
test -f /etc/ragos-inventory/clients.nix
test "$(nix-instantiate --eval --strict --json /etc/ragos-inventory/clients.nix)" = "[]"
grep -F 'inventoryRequireNonEmpty = false;' /var/lib/ragos/runtime/params.nix
grep -F 'inventoryDir = "/etc/ragos-inventory";' /var/lib/ragos/runtime/params.nix
grep -F 'runtimeSource = "runtime";' /var/lib/ragos/runtime/params.nix
test -f /run/ragos-inventory/dnsmasq-hosts.conf
journalctl -b -p warning..alert --no-pager | tail -n 120
REMOTE
  then
    return 1
  fi
  printf 'validated\n' >"$boot_state_log"
}

wait_for_ssh() {
  local ssh_log="$1"
  local timeout="${2:-$SSH_TIMEOUT_SECONDS}"
  local deadline="$((SECONDS + timeout))"

  while (( SECONDS < deadline )); do
    if with_ssh_tools sshpass -p "$ADMIN_PASSWORD" ssh \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=5 \
      "${ADMIN_USER}@${LAB_SERVER_IP}" \
      'true' >/dev/null 2>"$ssh_log"; then
      return 0
    fi
    sleep 10
  done

  return 1
}

transition_to_installed_disk_boot() {
  local xml cdrom_target
  xml="$(get_domain_xml)"
  cdrom_target="$(grep -oE "<target dev='[^']+' bus='sata'/>|<target dev='[^']+' bus='ide'/>" <<<"$xml" | head -n 1 | sed -E "s/.*dev='([^']+)'.*/\1/")"
  [[ -n "$cdrom_target" ]] || cdrom_target="sda"

  log "Parando a live ISO antes do primeiro boot em disco"
  virsh --connect "$LIBVIRT_URI" shutdown "$DOMAIN_NAME" >/dev/null 2>&1 || true

  for _ in $(seq 1 30); do
    if ! domain_is_running; then
      break
    fi
    sleep 2
  done

  if domain_is_running; then
    warn "Guest nao desligou em tempo util; forçando power off para evitar SQUASHFS errors da live"
    virsh --connect "$LIBVIRT_URI" destroy "$DOMAIN_NAME" >/dev/null 2>&1 || \
      die "Nao foi possivel desligar o dominio ${DOMAIN_NAME} antes de remover a ISO"
  fi

  log "Ejetando ISO do dominio ${DOMAIN_NAME} com o guest desligado"
  if ! virsh --connect "$LIBVIRT_URI" change-media "$DOMAIN_NAME" "$cdrom_target" --eject --config >/dev/null 2>&1; then
    warn "change-media falhou; tentando detach-disk em ${cdrom_target}"
    virsh --connect "$LIBVIRT_URI" detach-disk "$DOMAIN_NAME" "$cdrom_target" --config >/dev/null 2>&1 || \
      die "Nao foi possivel ejetar a ISO do dominio"
  fi

  log "Inicializando o dominio ${DOMAIN_NAME} apenas pelo disco instalado"
  virsh --connect "$LIBVIRT_URI" start "$DOMAIN_NAME" >/dev/null 2>&1 || \
    die "Falha ao iniciar o dominio ${DOMAIN_NAME} pelo disco instalado"
}

collect_failure_context() {
  local reason="$1"
  local guest_ip="${2:-}"
  local candidate_ip
  warn "Falha em ${reason}; coletando diagnosticos"
  dump_domain_state "failure"

  if [[ -z "$guest_ip" ]]; then
    while IFS= read -r candidate_ip; do
      [[ -n "$candidate_ip" ]] || continue
      if curl -fsS --max-time 3 "http://${candidate_ip}:8000/api/v1/status" >/dev/null 2>&1; then
        guest_ip="$candidate_ip"
        break
      fi
    done < <(guest_backend_ips || true)
  fi

  if [[ -n "$guest_ip" ]]; then
    curl -fsS --max-time 5 "http://${guest_ip}:8000/api/v1/status" >"$ARTIFACTS_DIR/failure.api-status.json" 2>/dev/null || true
    fetch_live_install_state_json "$guest_ip" >"$ARTIFACTS_DIR/failure.live-install-state.json" || true
    fetch_live_install_log_tail "$guest_ip" >"$ARTIFACTS_DIR/failure.live-install-log.txt" || true
  fi
}

main() {
  local iso_path guest_ip live_probe_log install_console_log install_state_log live_screenshot ocr_text boot_ssh_log boot_state_log payload_file ssh_log

  while (($# > 0)); do
    case "$1" in
      --iso)
        shift || die "Faltou valor para --iso"
        ISO_PATH="${1:-}"
        [[ -n "$ISO_PATH" ]] || die "Faltou valor para --iso"
        ;;
      --build-iso)
        BUILD_ISO=1
        ;;
      --no-recreate)
        RECREATE=0
        ;;
      --with-uplink)
        WITH_UPLINK=1
        ;;
      --no-uplink)
        WITH_UPLINK=0
        ;;
      --srv-mem)
        shift || die "Faltou valor para --srv-mem"
        LAB_SRV_MEM_MIB="${1:-}"
        [[ -n "$LAB_SRV_MEM_MIB" ]] || die "Faltou valor para --srv-mem"
        ;;
      --allow-degraded)
        ALLOW_DEGRADED=1
        ;;
      --artifacts-dir)
        shift || die "Faltou valor para --artifacts-dir"
        ARTIFACTS_DIR="${1:-}"
        [[ -n "$ARTIFACTS_DIR" ]] || die "Faltou valor para --artifacts-dir"
        ;;
      --lock-file)
        shift || die "Faltou valor para --lock-file"
        LOCK_FILE="${1:-}"
        [[ -n "$LOCK_FILE" ]] || die "Faltou valor para --lock-file"
        ;;
      --ui-timeout)
        shift || die "Faltou valor para --ui-timeout"
        UI_TIMEOUT_SECONDS="${1:-}"
        ;;
      --install-timeout)
        shift || die "Faltou valor para --install-timeout"
        INSTALL_TIMEOUT_SECONDS="${1:-}"
        ;;
      --boot-timeout)
        shift || die "Faltou valor para --boot-timeout"
        BOOT_TIMEOUT_SECONDS="${1:-}"
        ;;
      --ssh-timeout)
        shift || die "Faltou valor para --ssh-timeout"
        SSH_TIMEOUT_SECONDS="${1:-}"
        ;;
      --help)
        usage
        return 0
        ;;
      *)
        die "Opcao desconhecida: $1"
        ;;
    esac
    shift || true
  done

  mkdir -p "$ARTIFACTS_DIR"
  acquire_run_lock
  validate_lab_binary

  if (( BUILD_ISO )); then
    build_iso
  fi

  if ! iso_path="$(resolve_iso_path)"; then
    if (( BUILD_ISO )); then
      die "ISO nao encontrada mesmo apos build"
    fi
    log "ISO nao encontrada localmente; construindo porque foi solicitada validacao completa"
    build_iso
    iso_path="$(resolve_iso_path)" || die "ISO nao encontrada apos o build"
  fi

  log "ISO selecionada: ${iso_path}"
  log "Artefatos: ${ARTIFACTS_DIR}"

  if (( RECREATE )); then
    recreate_lab "$iso_path"
    dump_domain_state "after-recreate"
  else
    domain_exists || die "Dominio ${DOMAIN_NAME} inexistente; --no-recreate exige uma VM previamente criada"
    log "Reutilizando dominio existente ${DOMAIN_NAME} sem recriacao"
    dump_domain_state "existing-domain"
  fi
  assert_domain_contract

  if ! domain_is_running; then
    log "Iniciando dominio ${DOMAIN_NAME}"
    virsh --connect "$LIBVIRT_URI" start "$DOMAIN_NAME" >/dev/null
  fi

  live_probe_log="$ARTIFACTS_DIR/live-probe.log"
  live_screenshot="$ARTIFACTS_DIR/live-ui.png"
  ocr_text="$ARTIFACTS_DIR/live-ui.ocr.txt"
  payload_file="$ARTIFACTS_DIR/install-plan.json"

  log "Aguardando backend do installer ficar acessivel pela rede do guest"
  guest_ip="$(wait_for_guest_backend "$UI_TIMEOUT_SECONDS")" || {
    collect_failure_context "backend live inacessivel"
    die "Backend do installer nao respondeu em tempo util"
  }
  log "Backend do guest acessivel em ${guest_ip}"

  log "Validando backend do installer pelo canal HTTP"
  {
    curl -fsS "http://${guest_ip}:8000/api/v1/status"
    curl -fsS "http://${guest_ip}:8000/api/v1/netifs"
  } >"$live_probe_log"

  log "Coletando prova visual da UI da live ISO"
  local ui_deadline="$((SECONDS + UI_TIMEOUT_SECONDS))"
  while (( SECONDS < ui_deadline )); do
    if take_screenshot "$live_screenshot" && ocr_screenshot "$live_screenshot" "$ocr_text" && \
      grep -Eiq "(ragos|installer|instalador|instalacao)" "$ocr_text"; then
      log "UI da live ISO confirmada por screenshot + OCR"
      break
    fi
    sleep 10
  done
  if ! grep -Eiq "(ragos|installer|instalador|instalacao)" "$ocr_text"; then
    collect_failure_context "prova visual da UI"
    warn "OCR bruto do screenshot:"
    [[ -f "$ocr_text" ]] && cat "$ocr_text" >&2 || true
    die "A UI nao ficou visivel no live screenshot"
  fi

  log "Gerando payload unattended coerente com o lab"
  build_backend_install_payload \
    "$ARTIFACTS_DIR" \
    "$(curl -fsS "http://${guest_ip}:8000/api/v1/netifs")" \
    "$(fetch_guest_disks "$guest_ip")" >/dev/null

  log "Iniciando instalacao pelo backend HTTP do guest"
  install_console_log="$ARTIFACTS_DIR/install-console.log"
  install_state_log="$ARTIFACTS_DIR/install-state-poll.log"
  start_install_via_backend_api "$guest_ip" "$ARTIFACTS_DIR/install-plan.json" "$ARTIFACTS_DIR/install-secrets.json" \
    >"$install_console_log"

  log "Aguardando conclusao da instalacao no backend"
  if ! wait_for_install_completion "$guest_ip" "$INSTALL_TIMEOUT_SECONDS" "$install_state_log" >/dev/null; then
    collect_failure_context "instalacao via backend" "$guest_ip"
    die "Instalacao nao concluiu com sucesso"
  fi

  log "Instalacao concluida; desligando a live, ejetando ISO e inicializando do disco"
  transition_to_installed_disk_boot

  boot_ssh_log="$ARTIFACTS_DIR/boot-ssh.log"
  boot_state_log="$ARTIFACTS_DIR/boot-state.log"
  if ! wait_for_ssh "$boot_ssh_log" "$BOOT_TIMEOUT_SECONDS"; then
    collect_failure_context "boot apos eject da ISO"
    die "SSH do sistema instalado nao respondeu em ${LAB_SERVER_IP}"
  fi
  log "SSH do sistema instalado respondeu em ${LAB_SERVER_IP}"

  validate_after_install "$boot_ssh_log" "$boot_state_log" || {
    collect_failure_context "validacao do sistema instalado"
    die "A validacao do sistema instalado falhou"
  }

  if (( ALLOW_DEGRADED )); then
    log "Modo degraded permitido por flag explicita"
  fi

  dump_domain_state "after-success"
  log "Validacao concluida com sucesso"
  printf 'ISO=%s\n' "$iso_path"
  printf 'ARTIFACTS=%s\n' "$ARTIFACTS_DIR"
  printf 'LIVE_SCREENSHOT=%s\n' "$live_screenshot"
  printf 'LIVE_OCR=%s\n' "$ocr_text"
  printf 'INSTALL_LOG=%s\n' "$install_console_log"
  printf 'INSTALL_STATE_LOG=%s\n' "$install_state_log"
  printf 'BOOT_SSH_LOG=%s\n' "$boot_ssh_log"
}

trap 'collect_failure_context "linha ${LINENO}"' ERR

main "$@"
