#!/usr/bin/env bash
# Purpose: Solicitar variante dark/light do Plasma no cliente via console serial
# Category: branding
# Safety: safe
# Expected environment: dominio libvirt com console serial acessivel
# Requires: bash, virsh, nix

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./libvirt-capture-common.sh
source "$SCRIPT_DIR/libvirt-capture-common.sh"

LIBVIRT_URI="${LIBVIRT_URI:-qemu:///system}"
DOMAIN_NAME="${DOMAIN_NAME:-tc-02}"
LOGIN_USER="${LOGIN_USER:-admin}"
LOGIN_PASSWORD="${LOGIN_PASSWORD:-}"
VARIANT="${VARIANT:-dark}"
SERIAL_TIMEOUT_SECONDS="${SERIAL_TIMEOUT_SECONDS:-180}"
OUTPUT_LOG="${OUTPUT_LOG:-}"

usage() {
  cat <<EOF
Uso: $(basename "$0") [opcoes]

Solicita a proxima variante do Plasma para o usuario informado. A mudanca e
aplicada na proxima sessao grafica pelo init de branding do cliente.

Opcoes:
  --domain NOME              Dominio libvirt. Default: ${DOMAIN_NAME}
  --libvirt-uri URI          URI libvirt. Default: ${LIBVIRT_URI}
  --login-user USER          Usuario do console serial. Default: ${LOGIN_USER}
  --login-password SENHA     Senha do usuario do console serial.
  --variant NOME             dark|light. Default: ${VARIANT}
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
    --variant)
      shift
      VARIANT="${1:-}"
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
[[ "$VARIANT" == "dark" || "$VARIANT" == "light" ]] || brandlab_die "variante invalida: ${VARIANT}"

if [[ -z "$OUTPUT_LOG" ]]; then
  mkdir -p "$SCRIPT_DIR/../../../artifacts/branding/reports"
  OUTPUT_LOG="$SCRIPT_DIR/../../../artifacts/branding/reports/plasma-variant-${DOMAIN_NAME}-${VARIANT}.log"
fi

brandlab_run_serial_command \
  "$LIBVIRT_URI" \
  "$DOMAIN_NAME" \
  "$LOGIN_USER" \
  "$LOGIN_PASSWORD" \
  "$SERIAL_TIMEOUT_SECONDS" \
  "$OUTPUT_LOG" \
  "set -euo pipefail
ragos-plasma-set-preferred-variant '${VARIANT}'
rm -f \"\$HOME/.config/ragos/plasma-proof.env\"
echo requested_variant='${VARIANT}'"

printf '%s\n' "$OUTPUT_LOG"
