#!/usr/bin/env bash
# Purpose: Capturar janela de boot para evidencia visual real do Plymouth no BrandLab
# Category: branding
# Safety: destructive
# Expected environment: dominio libvirt dedicado ao lab grafico do cliente
# Requires: bash, virsh, nix

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./libvirt-capture-common.sh
source "$SCRIPT_DIR/libvirt-capture-common.sh"

REPO_ROOT="${REPO_ROOT:-$(brandlab_repo_root)}"
LIBVIRT_URI="${LIBVIRT_URI:-qemu:///system}"
DOMAIN_NAME="${DOMAIN_NAME:-tc-02}"
SCREENSHOTS_DIR="${SCREENSHOTS_DIR:-$REPO_ROOT/artifacts/branding/screenshots}"
WINDOW_SECONDS="${WINDOW_SECONDS:-45}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-0.5}"
BEST_FRAME_MAX_SECONDS="${BEST_FRAME_MAX_SECONDS:-10}"
REBOOT_DOMAIN="false"
START_DOMAIN="false"
ALLOW_INACTIVE_OUTPUT="false"
PLYMOUTH_EXPECTED_OCR_REGEX='(RAGOS)'
PLYMOUTH_BOOT_TRANSITION_OCR_REGEX='(TianoCore|Open Platform F[ei]rmware Development|Start boot option|PXE|iPXE|BdsDxe|NBP|Station IP address|Server IP address|Boot0001|Booting RAGOS generic)'
PLYMOUTH_REJECT_OCR_REGEX="(${PLYMOUTH_BOOT_TRANSITION_OCR_REGEX}|Favoritos|Todos os aplicativos|Configurac|Dolphin|Discover|Aplicativos|Sess[aã]o|Reiniciar|Desligar|[0-9]{2}:[0-9]{2})"

usage() {
  cat <<EOF
Uso: $(basename "$0") [opcoes]

Captura uma janela de boot do dominio e preserva frames para revisao do Plymouth.
Este fluxo e destrutivo quando reinicia um dominio em execucao.

Opcoes:
  --domain NOME              Dominio libvirt. Default: ${DOMAIN_NAME}
  --libvirt-uri URI          URI libvirt. Default: ${LIBVIRT_URI}
  --screenshots-dir DIR      Diretorio de artefatos. Default: ${SCREENSHOTS_DIR}
  --window-seconds S         Duracao da janela de captura. Default: ${WINDOW_SECONDS}
  --interval-seconds S       Intervalo entre frames. Default: ${INTERVAL_SECONDS}
  --best-frame-max-seconds S Janela maxima para escolher frame util. Default: ${BEST_FRAME_MAX_SECONDS}
  --reboot-domain            Reinicia o dominio antes da captura.
  --start-domain             Inicia o dominio se ele estiver desligado.
  --allow-inactive-output    Mantem frames mesmo quando o framebuffer estiver inativo.
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
    --window-seconds)
      shift
      WINDOW_SECONDS="${1:-}"
      ;;
    --interval-seconds)
      shift
      INTERVAL_SECONDS="${1:-}"
      ;;
    --best-frame-max-seconds)
      shift
      BEST_FRAME_MAX_SECONDS="${1:-}"
      ;;
    --reboot-domain)
      REBOOT_DOMAIN="true"
      ;;
    --start-domain)
      START_DOMAIN="true"
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
brandlab_domain_exists "$LIBVIRT_URI" "$DOMAIN_NAME" || brandlab_die "dominio inexistente: ${DOMAIN_NAME}"

case "$WINDOW_SECONDS" in
  ''|*[!0-9]*) brandlab_die "window-seconds invalido: ${WINDOW_SECONDS}" ;;
esac
[[ "$INTERVAL_SECONDS" =~ ^[0-9]+([.][0-9]+)?$ ]] || brandlab_die "interval-seconds invalido: ${INTERVAL_SECONDS}"
case "$BEST_FRAME_MAX_SECONDS" in
  ''|*[!0-9]*) brandlab_die "best-frame-max-seconds invalido: ${BEST_FRAME_MAX_SECONDS}" ;;
esac
(( WINDOW_SECONDS > 0 )) || brandlab_die "window-seconds deve ser maior que zero"
(( BEST_FRAME_MAX_SECONDS > 0 )) || brandlab_die "best-frame-max-seconds deve ser maior que zero"

select_best_frame="true"
if brandlab_domain_running "$LIBVIRT_URI" "$DOMAIN_NAME"; then
  [[ "$REBOOT_DOMAIN" == "true" ]] || brandlab_die "captura de Plymouth exige --reboot-domain quando o dominio esta rodando"
  brandlab_log "reiniciando ${DOMAIN_NAME} para captura de Plymouth"
  virsh --connect "$LIBVIRT_URI" reboot "$DOMAIN_NAME" >/dev/null \
    || brandlab_die "falha ao reiniciar ${DOMAIN_NAME}"
  select_best_frame="false"
else
  [[ "$START_DOMAIN" == "true" ]] || brandlab_die "captura de Plymouth exige --start-domain quando o dominio esta desligado"
  brandlab_log "iniciando ${DOMAIN_NAME} para captura de Plymouth"
  virsh --connect "$LIBVIRT_URI" start "$DOMAIN_NAME" >/dev/null \
    || brandlab_die "falha ao iniciar ${DOMAIN_NAME}"
fi

window_dir="${SCREENSHOTS_DIR}/plymouth-${DOMAIN_NAME}-window"
best_png="${SCREENSHOTS_DIR}/plymouth-${DOMAIN_NAME}-best.png"
best_ocr="${SCREENSHOTS_DIR}/plymouth-${DOMAIN_NAME}-best.ocr.txt"
best_meta="${SCREENSHOTS_DIR}/plymouth-${DOMAIN_NAME}-best.meta.txt"
index_file="${window_dir}/index.txt"

rm -rf "$window_dir"
mkdir -p "$window_dir" "$SCREENSHOTS_DIR"

frame=0
best_frame_png=""
best_frame_ocr=""
best_frame_meta=""
fallback_frame_png=""
fallback_frame_ocr=""
fallback_frame_meta=""
boot_transition_seen="false"
deadline="$((SECONDS + WINDOW_SECONDS))"
max_fallback_frame="$(awk -v max="$BEST_FRAME_MAX_SECONDS" -v interval="$INTERVAL_SECONDS" 'BEGIN { if (interval <= 0) { print 0; exit } printf "%d", int((max / interval) + 0.999999) }')"

while (( SECONDS < deadline )); do
  frame=$((frame + 1))
  stem="$(printf '%s/frame-%03d' "$window_dir" "$frame")"
  image_path="${stem}.png"
  meta_path="${stem}.meta.txt"

  if brandlab_domain_running "$LIBVIRT_URI" "$DOMAIN_NAME"; then
    brandlab_take_screenshot "$LIBVIRT_URI" "$DOMAIN_NAME" "$image_path"
  else
    printf 'frame=%03d status=domain-not-running captured_at=%s\n' \
      "$frame" "$(date --iso-8601=seconds)" >"$meta_path"
  fi

  sleep "$INTERVAL_SECONDS"
done

for png_path in "$window_dir"/frame-*.png; do
  [[ -f "$png_path" ]] || continue

  stem="${png_path%.png}"
  image_path="${png_path}"
  ocr_path="${stem}.ocr.txt"
  meta_path="${stem}.meta.txt"

  brandlab_write_ocr "$image_path" "$ocr_path"
  read -r width height <<<"$(brandlab_image_dimensions "$image_path")"
  mean="$(brandlab_image_mean "$image_path")"
  stddev="$(brandlab_image_stddev "$image_path")"
  sha="$(sha256sum "$image_path" | awk '{print $1}')"

  inactive_output="false"
  if brandlab_ocr_inactive_output "$ocr_path"; then
    inactive_output="true"
    boot_transition_seen="true"
  fi

  surface_match="unknown"
  surface_match_reason="boot_window_frame"
  if [[ "$inactive_output" != "true" ]]; then
    match_payload="$(brandlab_classify_surface_match "$ocr_path" "$PLYMOUTH_EXPECTED_OCR_REGEX" "$PLYMOUTH_REJECT_OCR_REGEX")"
    surface_match="${match_payload%%|*}"
    surface_match_reason="${match_payload#*|}"
    if grep -Eiq "$PLYMOUTH_BOOT_TRANSITION_OCR_REGEX" "$ocr_path"; then
      boot_transition_seen="true"
    fi
  fi

  brandlab_emit_capture_metadata \
    "$meta_path" "plymouth" "$DOMAIN_NAME" "$image_path" "$ocr_path" "virsh-screenshot-window" \
    "$inactive_output" "$width" "$height" "$mean" "$stddev" "$sha" "$surface_match" "$surface_match_reason"

  frame_number="${stem##*-}"
  frame_number="${frame_number#0}"
  [[ -n "$frame_number" ]] || frame_number=0

  if [[ "$inactive_output" == "false" && "$surface_match" == "expected" && -z "$best_frame_png" && ( "$select_best_frame" == "true" || "$boot_transition_seen" == "true" ) ]]; then
    best_frame_png="$image_path"
    best_frame_ocr="$ocr_path"
    best_frame_meta="$meta_path"
  elif [[ "$inactive_output" == "false" && "$surface_match" != "rejected" && -z "$fallback_frame_png" && "$select_best_frame" == "true" && "$frame_number" -le "$max_fallback_frame" ]]; then
    fallback_frame_png="$image_path"
    fallback_frame_ocr="$ocr_path"
    fallback_frame_meta="$meta_path"
  fi
done

{
  printf 'surface=plymouth\n'
  printf 'domain=%s\n' "$DOMAIN_NAME"
  printf 'window_seconds=%s\n' "$WINDOW_SECONDS"
  printf 'interval_seconds=%s\n' "$INTERVAL_SECONDS"
  printf 'best_frame_max_seconds=%s\n' "$BEST_FRAME_MAX_SECONDS"
  printf 'max_fallback_frame=%s\n' "$max_fallback_frame"
  printf 'select_best_frame=%s\n' "$select_best_frame"
  printf 'frames_captured=%s\n' "$frame"
  printf 'best_frame_png=%s\n' "${best_frame_png:-}"
  printf 'best_frame_meta=%s\n' "${best_frame_meta:-}"
  printf 'fallback_frame_png=%s\n' "${fallback_frame_png:-}"
  printf 'fallback_frame_meta=%s\n' "${fallback_frame_meta:-}"
} >"$index_file"

if [[ -n "$best_frame_png" ]]; then
  cp "$best_frame_png" "$best_png"
  cp "$best_frame_ocr" "$best_ocr"
  cp "$best_frame_meta" "$best_meta"
  brandlab_log "melhor frame de Plymouth salvo em ${best_png}"
  exit 0
fi

if [[ -n "$fallback_frame_png" ]]; then
  cp "$fallback_frame_png" "$best_png"
  cp "$fallback_frame_ocr" "$best_ocr"
  cp "$fallback_frame_meta" "$best_meta"
  brandlab_set_meta_value "$best_meta" "surface_match" "unknown"
  brandlab_set_meta_value "$best_meta" "surface_match_reason" "boot_window_fallback_without_branding_match"
fi

if [[ "$ALLOW_INACTIVE_OUTPUT" == "true" ]]; then
  brandlab_warn "nenhum frame de branding do Plymouth foi provado; janela salva em ${window_dir}"
  exit 0
fi

brandlab_die "nenhum frame de branding do Plymouth foi provado; veja ${index_file}"
