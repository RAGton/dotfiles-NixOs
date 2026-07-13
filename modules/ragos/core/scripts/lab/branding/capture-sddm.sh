#!/usr/bin/env bash
# Purpose: Capturar evidencia visual atual do SDDM do BrandLab via libvirt
# Category: branding
# Safety: safe
# Expected environment: dominio libvirt parado na tela de login grafico
# Requires: bash, virsh, nix

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./libvirt-capture-common.sh
source "$SCRIPT_DIR/libvirt-capture-common.sh"

REPO_ROOT="${REPO_ROOT:-$(brandlab_repo_root)}"
LIBVIRT_URI="${LIBVIRT_URI:-qemu:///system}"
DOMAIN_NAME="${DOMAIN_NAME:-tc-02}"
SCREENSHOTS_DIR="${SCREENSHOTS_DIR:-$REPO_ROOT/artifacts/branding/screenshots}"
ALLOW_INACTIVE_OUTPUT="false"
EXPECTED_OCR_REGEX='(Password|Login|Shutdown|Reboot|Suspend|Session|Sess[aã]o|Layout|Plasma \(Wayland\)|portugu[eé]s)'
REJECT_OCR_REGEX='(\[FAILED\]|\[DEPEND\]|Started Display Manager|Reached target|ragos-client-debug|systemctl status|libbz2\.so\.1)'

usage() {
  cat <<EOF
Uso: $(basename "$0") [opcoes]

Captura a tela atual do dominio para revisar o SDDM do RAGOS.

Opcoes:
  --domain NOME              Dominio libvirt. Default: ${DOMAIN_NAME}
  --libvirt-uri URI          URI libvirt. Default: ${LIBVIRT_URI}
  --screenshots-dir DIR      Diretorio de artefatos. Default: ${SCREENSHOTS_DIR}
  --expected-ocr REGEX       Regex OCR para promover a captura como SDDM provado.
  --reject-ocr REGEX         Regex OCR para marcar a captura como superficie inesperada.
  --allow-inactive-output    Nao falha quando o framebuffer estiver inativo.
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
    --screenshots-dir)
      shift
      SCREENSHOTS_DIR="${1:-}"
      ;;
    --expected-ocr)
      shift
      EXPECTED_OCR_REGEX="${1:-}"
      ;;
    --reject-ocr)
      shift
      REJECT_OCR_REGEX="${1:-}"
      ;;
    --allow-inactive-output)
      ALLOW_INACTIVE_OUTPUT="true"
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

brandlab_require_cmd bash virsh nix sha256sum
brandlab_capture_current_surface "sddm" "$LIBVIRT_URI" "$DOMAIN_NAME" "$SCREENSHOTS_DIR" "$ALLOW_INACTIVE_OUTPUT" "$EXPECTED_OCR_REGEX" "$REJECT_OCR_REGEX"
