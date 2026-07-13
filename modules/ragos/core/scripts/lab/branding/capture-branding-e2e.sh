#!/usr/bin/env bash
# Purpose: Provar visualmente Plymouth, SDDM e Plasma no mesmo ciclo do BrandLab
# Category: branding
# Safety: destructive
# Expected environment: dominio cliente do lab controlado por libvirt
# Requires: bash, virsh, nix

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./libvirt-capture-common.sh
source "$SCRIPT_DIR/libvirt-capture-common.sh"

REPO_ROOT="${REPO_ROOT:-$(brandlab_repo_root)}"
LIBVIRT_URI="${LIBVIRT_URI:-qemu:///system}"
DOMAIN_NAME="${DOMAIN_NAME:-tc-01}"
SCREENSHOTS_DIR="${SCREENSHOTS_DIR:-$REPO_ROOT/artifacts/branding/screenshots}"
REPORTS_DIR="${REPORTS_DIR:-$REPO_ROOT/artifacts/branding/reports}"
LOGIN_USER="${LOGIN_USER:-rag}"
LOGIN_PASSWORD="${LOGIN_PASSWORD:-Ragos!2026Think}"
SELECTION_KEYS_CSV="${SELECTION_KEYS_CSV:-}"
POST_LOGIN_KEYS_CSV="${POST_LOGIN_KEYS_CSV:-}"
SERIAL_VERIFY_USER="${SERIAL_VERIFY_USER:-}"
SERIAL_VERIFY_PASSWORD="${SERIAL_VERIFY_PASSWORD:-}"
SERIAL_TIMEOUT_SECONDS="${SERIAL_TIMEOUT_SECONDS:-600}"
LOGIN_SETTLE_SECONDS="${LOGIN_SETTLE_SECONDS:-20}"
PLASMA_DESKTOP_WAIT_SECONDS="${PLASMA_DESKTOP_WAIT_SECONDS:-25}"
SDDM_WAIT_SECONDS="${SDDM_WAIT_SECONDS:-240}"
SDDM_POLL_SECONDS="${SDDM_POLL_SECONDS:-5}"
PLYMOUTH_WINDOW_SECONDS="${PLYMOUTH_WINDOW_SECONDS:-45}"
PLYMOUTH_INTERVAL_SECONDS="${PLYMOUTH_INTERVAL_SECONDS:-0.5}"
PLYMOUTH_BEST_FRAME_MAX_SECONDS="${PLYMOUTH_BEST_FRAME_MAX_SECONDS:-10}"
CAPTURE_PLYMOUTH_MODE=""
LOGIN_INPUT_MODE="${LOGIN_INPUT_MODE:-password-only}"

SDDM_EXPECTED_OCR_REGEX='(Password|Login|Shutdown|Reboot|Suspend|Session|Sess[aã]o|Layout|Plasma \(Wayland\)|portugu[eé]s)'
SDDM_REJECT_OCR_REGEX='(\[FAILED\]|\[DEPEND\]|Started Display Manager|Reached target|ragos-client-debug|systemctl status|libbz2\.so\.1)'

usage() {
  cat <<EOF
Uso: $(basename "$0") [opcoes]

Executa um fluxo controlado de prova visual fim a fim:
1. captura Plymouth por start/reboot explicitamente sinalizado
2. aguarda a tela real do SDDM
3. autentica e prova o Plasma via captura + console serial
4. gera o report comparativo final do BrandLab

Opcoes:
  --domain NOME                    Dominio libvirt alvo. Default: ${DOMAIN_NAME}
  --libvirt-uri URI                URI libvirt. Default: ${LIBVIRT_URI}
  --screenshots-dir DIR            Diretorio de capturas. Default: ${SCREENSHOTS_DIR}
  --reports-dir DIR                Diretorio de reports. Default: ${REPORTS_DIR}
  --login-user USER                Usuario grafico. Default: ${LOGIN_USER}
  --login-password SENHA           Senha grafica. Default: ${LOGIN_PASSWORD}
  --login-input-mode MODE          password-only|username-password. Default: ${LOGIN_INPUT_MODE}
  --selection-keys CSV             Teclas extras no SDDM antes da senha.
  --post-login-keys CSV            Teclas opcionais apos o login.
  --serial-verify-user USER        Usuario do login serial. Default: mesmo do login grafico
  --serial-verify-password SENHA   Senha do login serial. Default: mesma do login grafico
  --serial-timeout S               Timeout da prova serial. Default: ${SERIAL_TIMEOUT_SECONDS}
  --login-settle-seconds S         Espera apos autenticar. Default: ${LOGIN_SETTLE_SECONDS}
  --plasma-desktop-wait-seconds S  Espera extra para o desktop estabilizar. Default: ${PLASMA_DESKTOP_WAIT_SECONDS}
  --sddm-wait-seconds S            Timeout para o greeter. Default: ${SDDM_WAIT_SECONDS}
  --sddm-poll-seconds S            Intervalo de polling do greeter. Default: ${SDDM_POLL_SECONDS}
  --capture-plymouth-start-domain  Inicia o dominio desligado e captura o boot.
  --capture-plymouth-reboot-domain Reinicia o dominio rodando e captura o boot.
  --plymouth-window-seconds S      Janela de captura do boot. Default: ${PLYMOUTH_WINDOW_SECONDS}
  --plymouth-interval-seconds S    Intervalo entre frames. Default: ${PLYMOUTH_INTERVAL_SECONDS}
  --plymouth-best-frame-max-seconds S
                                   Janela maxima do frame util. Default: ${PLYMOUTH_BEST_FRAME_MAX_SECONDS}
  --help                           Mostra esta ajuda.
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
    --reports-dir)
      shift
      REPORTS_DIR="${1:-}"
      ;;
    --login-user)
      shift
      LOGIN_USER="${1:-}"
      ;;
    --login-password)
      shift
      LOGIN_PASSWORD="${1:-}"
      ;;
    --login-input-mode)
      shift
      LOGIN_INPUT_MODE="${1:-}"
      ;;
    --selection-keys)
      shift
      SELECTION_KEYS_CSV="${1:-}"
      ;;
    --post-login-keys)
      shift
      POST_LOGIN_KEYS_CSV="${1:-}"
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
    --login-settle-seconds)
      shift
      LOGIN_SETTLE_SECONDS="${1:-}"
      ;;
    --plasma-desktop-wait-seconds)
      shift
      PLASMA_DESKTOP_WAIT_SECONDS="${1:-}"
      ;;
    --sddm-wait-seconds)
      shift
      SDDM_WAIT_SECONDS="${1:-}"
      ;;
    --sddm-poll-seconds)
      shift
      SDDM_POLL_SECONDS="${1:-}"
      ;;
    --capture-plymouth-start-domain)
      CAPTURE_PLYMOUTH_MODE="start"
      ;;
    --capture-plymouth-reboot-domain)
      CAPTURE_PLYMOUTH_MODE="reboot"
      ;;
    --plymouth-window-seconds)
      shift
      PLYMOUTH_WINDOW_SECONDS="${1:-}"
      ;;
    --plymouth-interval-seconds)
      shift
      PLYMOUTH_INTERVAL_SECONDS="${1:-}"
      ;;
    --plymouth-best-frame-max-seconds)
      shift
      PLYMOUTH_BEST_FRAME_MAX_SECONDS="${1:-}"
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
mkdir -p "$SCREENSHOTS_DIR" "$REPORTS_DIR"

[[ -n "$SERIAL_VERIFY_USER" ]] || SERIAL_VERIFY_USER="$LOGIN_USER"
[[ -n "$SERIAL_VERIFY_PASSWORD" ]] || SERIAL_VERIFY_PASSWORD="$LOGIN_PASSWORD"

case "$CAPTURE_PLYMOUTH_MODE" in
  start)
    bash "$SCRIPT_DIR/capture-plymouth.sh" \
      --domain "$DOMAIN_NAME" \
      --libvirt-uri "$LIBVIRT_URI" \
      --screenshots-dir "$SCREENSHOTS_DIR" \
      --window-seconds "$PLYMOUTH_WINDOW_SECONDS" \
      --interval-seconds "$PLYMOUTH_INTERVAL_SECONDS" \
      --best-frame-max-seconds "$PLYMOUTH_BEST_FRAME_MAX_SECONDS" \
      --start-domain
    ;;
  reboot)
    bash "$SCRIPT_DIR/capture-plymouth.sh" \
      --domain "$DOMAIN_NAME" \
      --libvirt-uri "$LIBVIRT_URI" \
      --screenshots-dir "$SCREENSHOTS_DIR" \
      --window-seconds "$PLYMOUTH_WINDOW_SECONDS" \
      --interval-seconds "$PLYMOUTH_INTERVAL_SECONDS" \
      --best-frame-max-seconds "$PLYMOUTH_BEST_FRAME_MAX_SECONDS" \
      --reboot-domain
    ;;
  "")
    brandlab_warn "captura de Plymouth nao solicitada; o report final mantera essa superficie como ausente"
    ;;
  *)
    brandlab_die "modo invalido de captura do Plymouth: ${CAPTURE_PLYMOUTH_MODE}"
    ;;
esac

plymouth_meta="${SCREENSHOTS_DIR}/plymouth-${DOMAIN_NAME}-best.meta.txt"
if [[ -n "$CAPTURE_PLYMOUTH_MODE" ]]; then
  [[ -f "$plymouth_meta" ]] || brandlab_die "captura de Plymouth nao gerou metadata: ${plymouth_meta}"
  [[ "$(brandlab_meta_value "$plymouth_meta" surface_match)" == "expected" ]] \
    || brandlab_die "captura de Plymouth nao provou o splash de branding em ${DOMAIN_NAME}"
fi

brandlab_log "aguardando o SDDM em ${DOMAIN_NAME}"
brandlab_wait_for_surface_match \
  "sddm" \
  "$LIBVIRT_URI" \
  "$DOMAIN_NAME" \
  "$SCREENSHOTS_DIR" \
  "$SDDM_WAIT_SECONDS" \
  "$SDDM_POLL_SECONDS" \
  "$SDDM_EXPECTED_OCR_REGEX" \
  "$SDDM_REJECT_OCR_REGEX" \
  || brandlab_die "nao foi possivel confirmar o SDDM em ${DOMAIN_NAME} dentro de ${SDDM_WAIT_SECONDS}s"

bash "$SCRIPT_DIR/capture-sddm.sh" \
  --domain "$DOMAIN_NAME" \
  --libvirt-uri "$LIBVIRT_URI" \
  --screenshots-dir "$SCREENSHOTS_DIR"

sddm_meta="${SCREENSHOTS_DIR}/sddm-${DOMAIN_NAME}-current.meta.txt"
[[ -f "$sddm_meta" ]] || brandlab_die "captura do SDDM nao gerou metadata: ${sddm_meta}"
[[ "$(brandlab_meta_value "$sddm_meta" surface_match)" == "expected" ]] \
  || brandlab_die "captura do SDDM nao ficou objetivamente provada em ${DOMAIN_NAME}"

bash "$SCRIPT_DIR/capture-plasma.sh" \
  --domain "$DOMAIN_NAME" \
  --libvirt-uri "$LIBVIRT_URI" \
  --screenshots-dir "$SCREENSHOTS_DIR" \
  --login-user "$LOGIN_USER" \
  --login-password "$LOGIN_PASSWORD" \
  --login-input-mode "$LOGIN_INPUT_MODE" \
  --selection-keys "$SELECTION_KEYS_CSV" \
  --post-login-keys "$POST_LOGIN_KEYS_CSV" \
  --login-settle-seconds "$LOGIN_SETTLE_SECONDS" \
  --serial-verify-user "$SERIAL_VERIFY_USER" \
  --serial-verify-password "$SERIAL_VERIFY_PASSWORD" \
  --serial-timeout "$SERIAL_TIMEOUT_SECONDS" \
  --allow-inactive-output

brandlab_log "aguardando o desktop do Plasma estabilizar em ${DOMAIN_NAME}"
sleep "$PLASMA_DESKTOP_WAIT_SECONDS"

bash "$SCRIPT_DIR/capture-plasma.sh" \
  --domain "$DOMAIN_NAME" \
  --libvirt-uri "$LIBVIRT_URI" \
  --screenshots-dir "$SCREENSHOTS_DIR" \
  --session-user "$LOGIN_USER" \
  --serial-verify-user "$SERIAL_VERIFY_USER" \
  --serial-verify-password "$SERIAL_VERIFY_PASSWORD" \
  --serial-timeout "$SERIAL_TIMEOUT_SECONDS" \
  --allow-inactive-output

plasma_meta="${SCREENSHOTS_DIR}/plasma-${DOMAIN_NAME}-current.meta.txt"
[[ -f "$plasma_meta" ]] || brandlab_die "captura do Plasma nao gerou metadata: ${plasma_meta}"
[[ "$(brandlab_meta_value "$plasma_meta" surface_match)" == "expected" ]] \
  || brandlab_die "captura do Plasma nao ficou objetivamente provada em ${DOMAIN_NAME}"

bash "$SCRIPT_DIR/compare-branding-baseline.sh" \
  --screenshots-dir "$SCREENSHOTS_DIR" \
  --reports-dir "$REPORTS_DIR"
