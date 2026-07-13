#!/usr/bin/env bash
# Purpose: Coletar prova serial do tema ativo do Plasma no cliente RAGOS
# Category: branding
# Safety: safe
# Expected environment: dominio libvirt com sessao grafica ja autenticada
# Requires: bash, virsh, nix

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./libvirt-capture-common.sh
source "$SCRIPT_DIR/libvirt-capture-common.sh"

LIBVIRT_URI="${LIBVIRT_URI:-qemu:///system}"
DOMAIN_NAME="${DOMAIN_NAME:-tc-02}"
LOGIN_USER="${LOGIN_USER:-admin}"
LOGIN_PASSWORD="${LOGIN_PASSWORD:-}"
SERIAL_TIMEOUT_SECONDS="${SERIAL_TIMEOUT_SECONDS:-180}"
OUTPUT_LOG="${OUTPUT_LOG:-}"

usage() {
  cat <<EOF
Uso: $(basename "$0") [opcoes]

Coleta evidencia serial do tema ativo do Plasma no cliente publicado.

Opcoes:
  --domain NOME              Dominio libvirt. Default: ${DOMAIN_NAME}
  --libvirt-uri URI          URI libvirt. Default: ${LIBVIRT_URI}
  --login-user USER          Usuario do console serial. Default: ${LOGIN_USER}
  --login-password SENHA     Senha do usuario do console serial.
  --serial-timeout S         Timeout do console serial. Default: ${SERIAL_TIMEOUT_SECONDS}
  --output-log ARQUIVO       Log da interacao serial.
  --help                     Mostra esta ajuda.
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --domain)
      shift
      DOMAIN_NAME="${1:-}"
      ;;
    --libvirt-uri)
      shift
      LIBVIRT_URI="${1:-}"
      ;;
    --login-user)
      shift
      LOGIN_USER="${1:-}"
      ;;
    --login-password)
      shift
      LOGIN_PASSWORD="${1:-}"
      ;;
    --serial-timeout)
      shift
      SERIAL_TIMEOUT_SECONDS="${1:-}"
      ;;
    --output-log)
      shift
      OUTPUT_LOG="${1:-}"
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      brandlab_die "opcao desconhecida: $1"
      ;;
  esac
  shift || true
done

brandlab_require_cmd bash virsh nix base64
[[ -n "$LOGIN_PASSWORD" ]] || brandlab_die "informe --login-password"

if [[ -z "$OUTPUT_LOG" ]]; then
  mkdir -p "$SCRIPT_DIR/../../../artifacts/branding/reports"
  OUTPUT_LOG="$SCRIPT_DIR/../../../artifacts/branding/reports/plasma-proof-${DOMAIN_NAME}.log"
fi

brandlab_run_serial_command \
  "$LIBVIRT_URI" \
  "$DOMAIN_NAME" \
  "$LOGIN_USER" \
  "$LOGIN_PASSWORD" \
  "$SERIAL_TIMEOUT_SECONDS" \
  "$OUTPUT_LOG" \
  "set -euo pipefail
echo '--- ragos-plasma-report ---'
ragos-plasma-report
echo '--- graphical processes ---'
pgrep -u \"\$USER\" -fa 'startplasma|plasma-session|plasmashell|kwin_wayland|ksmserver' || true"

printf '%s\n' "$OUTPUT_LOG"
