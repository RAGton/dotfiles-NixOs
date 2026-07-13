#!/usr/bin/env bash
# Purpose: Gerar checklist objetivo de revisao visual do BrandLab a partir do manifest
# Category: branding
# Safety: safe
# Expected environment: checkout local do RAGOS
# Requires: bash, coreutils

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
MANIFEST_PATH=""
OUTPUT_PATH=""

usage() {
  cat <<EOF
Uso: ${SCRIPT_NAME} [opcoes]

Gera um checklist Markdown para revisao objetiva do branding do RAGOS.

Opcoes:
  --manifest ARQUIVO  Manifest gerado por generate-branding-manifest.sh.
  --output ARQUIVO    Caminho da saida Markdown.
  --repo-root DIR     Raiz do checkout. Default: ${REPO_ROOT}
  --help              Mostra esta ajuda.
EOF
}

die() {
  printf '[error] %s\n' "$*" >&2
  exit 1
}

while (( $# > 0 )); do
  case "$1" in
    --manifest)
      [[ $# -ge 2 ]] || die "faltou valor para --manifest"
      MANIFEST_PATH="$2"
      shift 2
      ;;
    --output)
      [[ $# -ge 2 ]] || die "faltou valor para --output"
      OUTPUT_PATH="$2"
      shift 2
      ;;
    --repo-root)
      [[ $# -ge 2 ]] || die "faltou valor para --repo-root"
      REPO_ROOT="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      die "opcao desconhecida: $1"
      ;;
  esac
done

cd "$REPO_ROOT"

if [[ -z "$MANIFEST_PATH" ]]; then
  MANIFEST_PATH="${REPO_ROOT}/artifacts/branding/current-manifest.txt"
  bash "${REPO_ROOT}/scripts/lab/branding/generate-branding-manifest.sh" --output "$MANIFEST_PATH"
fi

[[ -f "$MANIFEST_PATH" ]] || die "manifest ausente: ${MANIFEST_PATH}"

if [[ -z "$OUTPUT_PATH" ]]; then
  OUTPUT_PATH="${REPO_ROOT}/artifacts/branding/current-review.md"
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

status_line() {
  local prefix="$1"
  grep -F "$prefix" "$MANIFEST_PATH" | head -n 1 || true
}

status_mark() {
  local line="$1"

  case "$line" in
    *'|present|'*)
      printf 'PASS'
      ;;
    *'|absent|'*)
      printf 'WARN'
      ;;
    *'|missing|'*)
      printf 'FAIL'
      ;;
    *)
      printf 'INFO'
      ;;
  esac
}

plymouth_line="$(status_line 'surface|plymouth|declarative-theme|')"
sddm_line="$(status_line 'surface|sddm|declarative-theme|')"
plasma_generic_line="$(status_line 'surface|plasma|desktop-generic-import|')"
plasma_lab_line="$(status_line 'surface|plasma|desktop-lab-import|')"
plasma_package_line="$(status_line 'surface|plasma|package|')"
plasma_flake_package_line="$(status_line 'surface|plasma|flake-package|')"
plasma_kde_store_line="$(status_line 'surface|plasma|kde-store-bundles|')"
look_and_feel_dark_line="$(status_line 'surface|plasma|look-and-feel-dark|')"
look_and_feel_light_line="$(status_line 'surface|plasma|look-and-feel-light|')"
desktoptheme_dark_line="$(status_line 'surface|plasma|desktoptheme-dark|')"
desktoptheme_light_line="$(status_line 'surface|plasma|desktoptheme-light|')"
colorscheme_dark_line="$(status_line 'surface|plasma|colorscheme-dark|')"
colorscheme_light_line="$(status_line 'surface|plasma|colorscheme-light|')"
wallpaper_dark_line="$(status_line 'surface|plasma|wallpaper-dark|')"
wallpaper_light_line="$(status_line 'surface|plasma|wallpaper-light|')"
plasma_apply_line="$(status_line 'surface|plasma|lookandfeel-apply|')"
variant_proof_line="$(status_line 'surface|plasma|variant-proof|')"
gtk_line="$(status_line 'surface|gtk|custom-theme|')"
runtime_line="$(status_line 'surface|runtime|doctor|')"

plymouth_mark="$(status_mark "$plymouth_line")"
sddm_mark="$(status_mark "$sddm_line")"
plasma_generic_mark="$(status_mark "$plasma_generic_line")"
plasma_lab_mark="$(status_mark "$plasma_lab_line")"
plasma_package_mark="$(status_mark "$plasma_package_line")"
plasma_flake_package_mark="$(status_mark "$plasma_flake_package_line")"
plasma_kde_store_mark="$(status_mark "$plasma_kde_store_line")"
look_and_feel_dark_mark="$(status_mark "$look_and_feel_dark_line")"
look_and_feel_light_mark="$(status_mark "$look_and_feel_light_line")"
desktoptheme_dark_mark="$(status_mark "$desktoptheme_dark_line")"
desktoptheme_light_mark="$(status_mark "$desktoptheme_light_line")"
colorscheme_dark_mark="$(status_mark "$colorscheme_dark_line")"
colorscheme_light_mark="$(status_mark "$colorscheme_light_line")"
wallpaper_dark_mark="$(status_mark "$wallpaper_dark_line")"
wallpaper_light_mark="$(status_mark "$wallpaper_light_line")"
plasma_apply_mark="$(status_mark "$plasma_apply_line")"
variant_proof_mark="$(status_mark "$variant_proof_line")"
gtk_mark="$(status_mark "$gtk_line")"
runtime_mark="$(status_mark "$runtime_line")"

cat >"$OUTPUT_PATH" <<EOF
# BrandLab Review

Gerado por: \`scripts/lab/branding/render-branding-review.sh\`
Manifesto usado: \`${MANIFEST_PATH#${REPO_ROOT}/}\`

## Estado objetivo detectado

- [${plymouth_mark}] Plymouth declarativo: \`${plymouth_line}\`
- [${sddm_mark}] SDDM declarativo: \`${sddm_line}\`
- [${plasma_generic_mark}] Plasma generic importa branding: \`${plasma_generic_line}\`
- [${plasma_lab_mark}] Plasma lab importa branding: \`${plasma_lab_line}\`
- [${plasma_package_mark}] Pacote declarativo do Plasma: \`${plasma_package_line}\`
- [${plasma_flake_package_mark}] Pacote exposto no flake: \`${plasma_flake_package_line}\`
- [${plasma_kde_store_mark}] Bundles para KDE Store: \`${plasma_kde_store_line}\`
- [${look_and_feel_dark_mark}] Global Theme dark: \`${look_and_feel_dark_line}\`
- [${look_and_feel_light_mark}] Global Theme light: \`${look_and_feel_light_line}\`
- [${desktoptheme_dark_mark}] Plasma Style dark: \`${desktoptheme_dark_line}\`
- [${desktoptheme_light_mark}] Plasma Style light: \`${desktoptheme_light_line}\`
- [${colorscheme_dark_mark}] Color Scheme dark: \`${colorscheme_dark_line}\`
- [${colorscheme_light_mark}] Color Scheme light: \`${colorscheme_light_line}\`
- [${wallpaper_dark_mark}] Wallpaper dark: \`${wallpaper_dark_line}\`
- [${wallpaper_light_mark}] Wallpaper light: \`${wallpaper_light_line}\`
- [${plasma_apply_mark}] Aplicacao declarativa de Look and Feel: \`${plasma_apply_line}\`
- [${variant_proof_mark}] Prova local de variante aplicada: \`${variant_proof_line}\`
- [${runtime_mark}] Evidencia de runtime via CLI: \`${runtime_line}\`
- [${gtk_mark}] GTK no estado atual: \`${gtk_line}\`

## Checklist visual obrigatorio

- [ ] Paleta coerente entre Plymouth, SDDM e Plasma.
  Passa se dark e light preservarem o mesmo acento tecnico, com neutros serios e sem visual gamer.
- [ ] Contraste suficiente para leitura no boot e login.
  Passa se textos, campos e barra de progresso permanecerem legiveis sem depender de brilho excessivo.
- [ ] Hierarquia visual clara.
  Passa se marca, area de autenticacao, painel e wallpaper nao competirem entre si.
- [ ] Densidade e espacamento estaveis.
  Passa se a tela de login nao parecer apertada e o desktop nao depender so do wallpaper para parecer acabado.
- [ ] Aparencia de produto serio.
  Passa se o conjunto comunicar controle industrial elegante, previsibilidade e precisao.

## O que este artefato nao prova sozinho

- Nenhuma screenshot foi capturada por este script.
- Qualidade visual final ainda exige inspecao humana ou captura controlada em lab.
- GTK nao deve ser tratado como coberto enquanto o repositorio nao declarar tema proprio para essa superficie.

## Evidencia complementar recomendada

- \`bash scripts/tests/test-brandlab-contract.sh\`
- \`ragos branding doctor > artifacts/branding/runtime-branding-doctor.txt\`
- Se houver captura visual real, anexe em \`artifacts/branding/\` com nome que identifique perfil e data.
EOF
