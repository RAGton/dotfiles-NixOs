#!/usr/bin/env bash
# Purpose: Comparar baseline do BrandLab com evidencias atuais de runtime e capturas visuais
# Category: branding
# Safety: safe
# Expected environment: checkout local do RAGOS com manifest e artefatos locais
# Requires: bash, coreutils, diff, ripgrep, sha256sum

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-$REPO_ROOT/artifacts/branding}"
SCREENSHOTS_DIR="${SCREENSHOTS_DIR:-$ARTIFACTS_DIR/screenshots}"
REPORTS_DIR="${REPORTS_DIR:-$ARTIFACTS_DIR/reports}"
BASELINE_MANIFEST="${BASELINE_MANIFEST:-$ARTIFACTS_DIR/baseline-manifest.txt}"
CURRENT_MANIFEST="${CURRENT_MANIFEST:-$ARTIFACTS_DIR/current-manifest.txt}"
REVIEW_OUTPUT="${REVIEW_OUTPUT:-$REPORTS_DIR/current-branding-comparison.md}"
DIFF_OUTPUT="${DIFF_OUTPUT:-$REPORTS_DIR/current-manifest-vs-baseline.diff}"
RUNTIME_OUTPUT="${RUNTIME_OUTPUT:-$ARTIFACTS_DIR/runtime-branding-doctor.txt}"
RUNTIME_MODE="${RUNTIME_MODE:-auto}"

usage() {
  cat <<EOF
Uso: $(basename "$0") [opcoes]

Compara o baseline do BrandLab com o estado atual do checkout e com as evidencias
visuais disponiveis em artifacts/branding/screenshots.

Opcoes:
  --artifacts-dir DIR     Base de artifacts. Default: ${ARTIFACTS_DIR}
  --screenshots-dir DIR   Diretorio de capturas. Default: ${SCREENSHOTS_DIR}
  --reports-dir DIR       Diretorio de reports. Default: ${REPORTS_DIR}
  --baseline FILE         Manifest baseline. Default: ${BASELINE_MANIFEST}
  --current FILE          Manifest atual. Default: ${CURRENT_MANIFEST}
  --output FILE           Report Markdown. Default: ${REVIEW_OUTPUT}
  --diff-output FILE      Diff do manifest. Default: ${DIFF_OUTPUT}
  --runtime-output FILE   Saida do branding doctor. Default: ${RUNTIME_OUTPUT}
  --runtime-mode MODE     auto|skip. Default: ${RUNTIME_MODE}
  --help                  Mostra esta ajuda.
EOF
}

die() {
  printf '[error] %s\n' "$*" >&2
  exit 1
}

while (( $# > 0 )); do
  case "$1" in
    --artifacts-dir)
      shift
      ARTIFACTS_DIR="${1:-}"
      ;;
    --screenshots-dir)
      shift
      SCREENSHOTS_DIR="${1:-}"
      ;;
    --reports-dir)
      shift
      REPORTS_DIR="${1:-}"
      ;;
    --baseline)
      shift
      BASELINE_MANIFEST="${1:-}"
      ;;
    --current)
      shift
      CURRENT_MANIFEST="${1:-}"
      ;;
    --output)
      shift
      REVIEW_OUTPUT="${1:-}"
      ;;
    --diff-output)
      shift
      DIFF_OUTPUT="${1:-}"
      ;;
    --runtime-output)
      shift
      RUNTIME_OUTPUT="${1:-}"
      ;;
    --runtime-mode)
      shift
      RUNTIME_MODE="${1:-}"
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      die "opcao desconhecida: $1"
      ;;
  esac
  shift || true
done

mkdir -p "$ARTIFACTS_DIR" "$SCREENSHOTS_DIR" "$REPORTS_DIR"

if [[ ! -f "$CURRENT_MANIFEST" ]]; then
  bash "$REPO_ROOT/scripts/lab/branding/generate-branding-manifest.sh" --output "$CURRENT_MANIFEST"
fi

[[ -f "$BASELINE_MANIFEST" ]] || die "baseline ausente: ${BASELINE_MANIFEST}"
[[ -f "$CURRENT_MANIFEST" ]] || die "manifest atual ausente: ${CURRENT_MANIFEST}"

run_runtime_doctor() {
  local exit_code=0
  local command_used=""

  case "$RUNTIME_MODE" in
    auto)
      if command -v ragos >/dev/null 2>&1; then
        command_used="ragos branding doctor"
        if ! ragos branding doctor >"$RUNTIME_OUTPUT" 2>&1; then
          exit_code=$?
        fi
      elif command -v nix >/dev/null 2>&1; then
        command_used="nix --extra-experimental-features 'nix-command flakes' run .#ragos -- branding doctor"
        if ! nix --extra-experimental-features 'nix-command flakes' run .#ragos -- branding doctor >"$RUNTIME_OUTPUT" 2>&1; then
          exit_code=$?
        fi
      else
        command_used="indisponivel"
        printf 'runtime_branding_doctor: indisponivel\n' >"$RUNTIME_OUTPUT"
        exit_code=127
      fi
      ;;
    skip)
      command_used="skip"
      printf 'runtime_branding_doctor: skipped\n' >"$RUNTIME_OUTPUT"
      ;;
    *)
      die "runtime-mode invalido: ${RUNTIME_MODE}"
      ;;
  esac

  printf '%s\n' "$command_used" >"${REPORTS_DIR}/runtime-branding-command.txt"
  printf '%s\n' "$exit_code" >"${REPORTS_DIR}/runtime-branding-exit-code.txt"
}

latest_capture_meta() {
  local surface="$1"

  find "$SCREENSHOTS_DIR" -maxdepth 1 -type f -name "${surface}-*.meta.txt" -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr \
    | head -n 1 \
    | awk '{print $2}'
}

meta_value() {
  local key="$1"
  local file="$2"

  sed -n "s/^${key}=//p" "$file" | head -n 1
}

surface_status() {
  local meta_file="$1"

  if [[ -z "$meta_file" || ! -f "$meta_file" ]]; then
    printf 'MISSING'
    return
  fi

  if [[ "$(meta_value inactive_output "$meta_file")" == "true" ]]; then
    printf 'INACTIVE'
    return
  fi

  case "$(meta_value surface_match "$meta_file")" in
    expected)
      printf 'CAPTURED'
      ;;
    rejected)
      printf 'UNUSABLE'
      ;;
    *)
      printf 'REVIEW'
      ;;
  esac
}

surface_reason() {
  local meta_file="$1"

  if [[ -z "$meta_file" || ! -f "$meta_file" ]]; then
    printf 'no_capture'
    return
  fi

  if [[ "$(meta_value inactive_output "$meta_file")" == "true" ]]; then
    printf 'inactive_output'
    return
  fi

  printf '%s' "$(meta_value surface_match_reason "$meta_file")"
}

surface_report_line() {
  local surface="$1"
  local meta_file="$2"
  local status="$3"
  local reason="$4"

  if [[ -z "$meta_file" || ! -f "$meta_file" ]]; then
    printf -- "- [%s] %s: sem captura atual.\n" "$status" "$surface"
    return
  fi

  local image_path image_sha width height mean stddev ocr_path ocr_excerpt
  image_path="$(meta_value image_path "$meta_file")"
  image_sha="$(meta_value image_sha256 "$meta_file")"
  width="$(meta_value width "$meta_file")"
  height="$(meta_value height "$meta_file")"
  mean="$(meta_value grayscale_mean "$meta_file")"
  stddev="$(meta_value grayscale_stddev "$meta_file")"
  ocr_path="$(meta_value ocr_path "$meta_file")"
  ocr_excerpt=""
  if [[ -f "$ocr_path" ]]; then
    ocr_excerpt="$(tr '\n' ' ' <"$ocr_path" | sed 's/[[:space:]]\+/ /g' | cut -c1-140)"
  fi
  ocr_excerpt="${ocr_excerpt//\`/\'}"

  printf -- "- [%s] %s: %s | sha256 %s | %sx%s | mean=%s | stddev=%s | OCR \"%s\"\n" \
    "$status" "$surface" "${image_path#${REPO_ROOT}/}" "$image_sha" "$width" "$height" "$mean" "$stddev" "$ocr_excerpt"
  printf -- "  motivo: %s\n" "$reason"
}

run_runtime_doctor

if diff -u "$BASELINE_MANIFEST" "$CURRENT_MANIFEST" >"$DIFF_OUTPUT"; then
  manifest_drift="none"
else
  manifest_drift="present"
fi

plymouth_meta="$(latest_capture_meta plymouth)"
sddm_meta="$(latest_capture_meta sddm)"
plasma_meta="$(latest_capture_meta plasma)"

plymouth_status="$(surface_status "$plymouth_meta")"
sddm_status="$(surface_status "$sddm_meta")"
plasma_status="$(surface_status "$plasma_meta")"
plymouth_reason="$(surface_reason "$plymouth_meta")"
sddm_reason="$(surface_reason "$sddm_meta")"
plasma_reason="$(surface_reason "$plasma_meta")"

runtime_exit_code="$(cat "${REPORTS_DIR}/runtime-branding-exit-code.txt")"
runtime_command="$(cat "${REPORTS_DIR}/runtime-branding-command.txt")"
runtime_summary="$(sed -n '1,12p' "$RUNTIME_OUTPUT" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | cut -c1-220)"
runtime_summary="${runtime_summary//\`/\'}"

cat >"$REVIEW_OUTPUT" <<EOF
# BrandLab Comparative Review

Gerado por: \`scripts/lab/branding/compare-branding-baseline.sh\`
Baseline: \`${BASELINE_MANIFEST#${REPO_ROOT}/}\`
Manifest atual: \`${CURRENT_MANIFEST#${REPO_ROOT}/}\`

## Runtime

- comando: \`${runtime_command}\`
- exit_code: \`${runtime_exit_code}\`
- artefato: \`${RUNTIME_OUTPUT#${REPO_ROOT}/}\`
- resumo: \`${runtime_summary}\`

## Manifest drift

- status: \`${manifest_drift}\`
- diff: \`${DIFF_OUTPUT#${REPO_ROOT}/}\`

## Evidencia visual atual

$(surface_report_line "Plymouth" "$plymouth_meta" "$plymouth_status" "$plymouth_reason")
$(surface_report_line "SDDM" "$sddm_meta" "$sddm_status" "$sddm_reason")
$(surface_report_line "Plasma" "$plasma_meta" "$plasma_status" "$plasma_reason")

## Revisao comparativa

- [ ] Coerencia de paleta entre boot, login e desktop.
  Provar com capturas uteis de Plymouth, SDDM e Plasma; hoje vale apenas para superficies com status \`CAPTURED\`.
- [ ] Contraste e legibilidade.
  Confirmar que os elementos principais permanecem legiveis nas capturas e nao dependem de brilho agressivo.
- [ ] Consistencia entre superficies.
  Comparar fundo, acentos, densidade e hierarquia sem afirmar aprovacao quando alguma superficie estiver \`MISSING\`, \`INACTIVE\`, \`REVIEW\` ou \`UNUSABLE\`.
- [ ] Alinhamento com a identidade do RAGOS.
  Verificar sobriedade tecnica, previsibilidade e aparencia de produto serio a partir dos artefatos acima.
- [ ] Drift visual.
  Use o diff do manifest para wiring/assets e as capturas para drift perceptivo.

## Limites atuais desta execucao

- Plymouth so pode ser provado por reboot/start controlado de VM; este script nao inventa esse estado.
- SDDM e Plasma dependem de framebuffer grafico ativo no dominio no momento da captura.
- GTK continua fora do escopo de prova automatica enquanto nao houver tema declarativo no repo.
- Nenhuma conclusao deve ser tratada como aprovacao visual sem apontar para um artefato capturado acima.
EOF

printf '%s\n' "$REVIEW_OUTPUT"
