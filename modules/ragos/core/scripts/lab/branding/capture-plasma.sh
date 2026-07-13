#!/usr/bin/env bash
# Purpose: Capturar evidencia visual atual do Plasma do BrandLab via libvirt
# Category: branding
# Safety: safe
# Expected environment: dominio libvirt com sessao grafica ja exibida
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
EXPECTED_OCR_REGEX=''
REJECT_OCR_REGEX='(\[FAILED\]|\[DEPEND\]|Started Display Manager|Reached target|ragos-client-debug|systemctl status|libbz2\.so\.1|Sess[aã]o|Layout|Plasma \(Wayland\)|portugu[eé]s)'
LOGIN_USER="${LOGIN_USER:-}"
LOGIN_PASSWORD="${LOGIN_PASSWORD:-}"
SESSION_USER="${SESSION_USER:-}"
SELECTION_KEYS_CSV="${SELECTION_KEYS_CSV:-}"
POST_LOGIN_KEYS_CSV="${POST_LOGIN_KEYS_CSV:-}"
LOGIN_SETTLE_SECONDS="${LOGIN_SETTLE_SECONDS:-20}"
SERIAL_VERIFY_USER="${SERIAL_VERIFY_USER:-}"
SERIAL_VERIFY_PASSWORD="${SERIAL_VERIFY_PASSWORD:-}"
SERIAL_TIMEOUT_SECONDS="${SERIAL_TIMEOUT_SECONDS:-600}"
LOGIN_INPUT_MODE="${LOGIN_INPUT_MODE:-password-only}"

usage() {
  cat <<EOF
Uso: $(basename "$0") [opcoes]

Captura a tela atual do dominio para revisar o Plasma do RAGOS.
Se receber credenciais, executa o login via SDDM antes da captura e prova a
sessao grafica via console serial.

Opcoes:
  --domain NOME              Dominio libvirt. Default: ${DOMAIN_NAME}
  --libvirt-uri URI          URI libvirt. Default: ${LIBVIRT_URI}
  --screenshots-dir DIR      Diretorio de artefatos. Default: ${SCREENSHOTS_DIR}
  --expected-ocr REGEX       Regex OCR para promover a captura como Plasma provado.
  --reject-ocr REGEX         Regex OCR para marcar a captura como superficie inesperada.
  --login-user USER          Usuario para login grafico antes da captura.
  --login-password SENHA     Senha do usuario para login grafico.
  --session-user USER        Usuario cuja sessao grafica deve ser provada sem reenviar login.
  --selection-keys CSV       Teclas extras antes da senha, ex.: KEY_RIGHT,KEY_RIGHT
  --post-login-keys CSV      Teclas opcionais apos o login, ex.: KEY_LEFTALT,KEY_SPACE
  --login-input-mode MODE    password-only|username-password. Default: ${LOGIN_INPUT_MODE}
  --login-settle-seconds S   Espera apos autenticar. Default: ${LOGIN_SETTLE_SECONDS}
  --serial-verify-user USER  Usuario para login serial. Default: mesmo de --login-user
  --serial-verify-password P Senha para login serial. Default: mesma de --login-password
  --serial-timeout S         Timeout da prova serial. Default: ${SERIAL_TIMEOUT_SECONDS}
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
    --login-user)
      shift
      LOGIN_USER="${1:-}"
      ;;
    --login-password)
      shift
      LOGIN_PASSWORD="${1:-}"
      ;;
    --session-user)
      shift
      SESSION_USER="${1:-}"
      ;;
    --selection-keys)
      shift
      SELECTION_KEYS_CSV="${1:-}"
      ;;
    --post-login-keys)
      shift
      POST_LOGIN_KEYS_CSV="${1:-}"
      ;;
    --login-input-mode)
      shift
      LOGIN_INPUT_MODE="${1:-}"
      ;;
    --login-settle-seconds)
      shift
      LOGIN_SETTLE_SECONDS="${1:-}"
      ;;
    --serial-verify-user)
      shift
      SERIAL_VERIFY_USER="${1:-}"
      ;;
    --serial-verify-password)
      shift
      SERIAL_VERIFY_PASSWORD="${1:-}"
      ;;
    --serial-timeout)
      shift
      SERIAL_TIMEOUT_SECONDS="${1:-}"
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
[[ "$LOGIN_INPUT_MODE" == "password-only" || "$LOGIN_INPUT_MODE" == "username-password" ]] \
  || brandlab_die "login-input-mode invalido: ${LOGIN_INPUT_MODE}"

if [[ -n "$LOGIN_USER" && -z "$SESSION_USER" ]]; then
  SESSION_USER="$LOGIN_USER"
fi

if [[ -n "$LOGIN_USER" || -n "$LOGIN_PASSWORD" ]]; then
  [[ -n "$LOGIN_USER" && -n "$LOGIN_PASSWORD" ]] || brandlab_die "login grafico exige --login-user e --login-password juntos"
  brandlab_log "aplicando login grafico via SDDM para ${LOGIN_USER} em ${DOMAIN_NAME}"
  brandlab_send_key_csv "$LIBVIRT_URI" "$DOMAIN_NAME" "$SELECTION_KEYS_CSV"
  if [[ "$LOGIN_INPUT_MODE" == "username-password" ]]; then
    brandlab_send_text_to_sddm "$LIBVIRT_URI" "$DOMAIN_NAME" "$LOGIN_USER"
    brandlab_send_domain_keys "$LIBVIRT_URI" "$DOMAIN_NAME" KEY_ENTER
    sleep 1
  fi
  brandlab_send_password_to_sddm "$LIBVIRT_URI" "$DOMAIN_NAME" "$LOGIN_PASSWORD"
  brandlab_send_domain_keys "$LIBVIRT_URI" "$DOMAIN_NAME" KEY_ENTER
  sleep "$LOGIN_SETTLE_SECONDS"
  brandlab_send_key_csv "$LIBVIRT_URI" "$DOMAIN_NAME" "$POST_LOGIN_KEYS_CSV"
  [[ -n "$POST_LOGIN_KEYS_CSV" ]] && sleep 2
fi

if [[ -n "$SESSION_USER" ]]; then
  [[ -n "$SERIAL_VERIFY_USER" ]] || SERIAL_VERIFY_USER="$SESSION_USER"
  [[ -n "$SERIAL_VERIFY_PASSWORD" ]] || SERIAL_VERIFY_PASSWORD="$LOGIN_PASSWORD"
  [[ -n "$SERIAL_VERIFY_PASSWORD" ]] || brandlab_die "prova serial da sessao exige --serial-verify-password ou --login-password"
fi

brandlab_capture_current_surface "plasma" "$LIBVIRT_URI" "$DOMAIN_NAME" "$SCREENSHOTS_DIR" "$ALLOW_INACTIVE_OUTPUT" "$EXPECTED_OCR_REGEX" "$REJECT_OCR_REGEX"

plasma_meta="${SCREENSHOTS_DIR}/plasma-${DOMAIN_NAME}-current.meta.txt"

if [[ -n "$SESSION_USER" ]]; then
  session_proof_log="${SCREENSHOTS_DIR}/plasma-${DOMAIN_NAME}-current.session-proof.log"
  brandlab_verify_graphical_session_via_serial \
    "$LIBVIRT_URI" \
    "$DOMAIN_NAME" \
    "$SERIAL_VERIFY_USER" \
    "$SERIAL_VERIFY_PASSWORD" \
    "$SESSION_USER" \
    "$SERIAL_TIMEOUT_SECONDS" \
    "$session_proof_log"

  brandlab_set_meta_value "$plasma_meta" "session_proof_log" "$session_proof_log"
  brandlab_set_meta_value "$plasma_meta" "graphical_session_verified" "true"
  brandlab_set_meta_value "$plasma_meta" "session_user" "$SESSION_USER"

  sddm_meta="$(brandlab_latest_capture_for_surface "$SCREENSHOTS_DIR" sddm)"
  plasma_sha="$(brandlab_meta_value "$plasma_meta" image_sha256)"
  if [[ -n "$sddm_meta" && -f "$sddm_meta" ]]; then
    sddm_sha="$(brandlab_meta_value "$sddm_meta" image_sha256)"
    if [[ -n "$sddm_sha" && "$sddm_sha" == "$plasma_sha" ]]; then
      brandlab_set_meta_value "$plasma_meta" "surface_match" "rejected"
      brandlab_set_meta_value "$plasma_meta" "surface_match_reason" "same_as_sddm_capture"
      brandlab_die "captura de plasma apos login ainda coincide com a captura do SDDM"
    fi
  fi

  if [[ "$(brandlab_meta_value "$plasma_meta" inactive_output)" != "true" && "$(brandlab_meta_value "$plasma_meta" surface_match)" != "rejected" ]]; then
    brandlab_set_meta_value "$plasma_meta" "surface_match" "expected"
    brandlab_set_meta_value "$plasma_meta" "surface_match_reason" "serial_graphical_session"
    brandlab_log "sessao grafica do Plasma provada por captura + serial em ${DOMAIN_NAME}"
  fi
fi
