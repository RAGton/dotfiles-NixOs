#!/usr/bin/env bash
# Purpose: Gerar manifest deterministico do BrandLab a partir do wiring real de branding
# Category: branding
# Safety: safe
# Expected environment: checkout local do RAGOS
# Requires: bash, coreutils, ripgrep, sha256sum

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
OUTPUT_PATH=""

usage() {
  cat <<EOF
Uso: ${SCRIPT_NAME} [opcoes]

Gera um manifest deterministico com superficies de branding e hashes dos assets
canonicos do RAGOS.

Opcoes:
  --output ARQUIVO    Grava a saida no arquivo informado.
  --repo-root DIR     Raiz do checkout. Default: ${REPO_ROOT}
  --help              Mostra esta ajuda.
EOF
}

die() {
  printf '[error] %s\n' "$*" >&2
  exit 1
}

require_file() {
  local file="$1"
  [[ -f "$file" ]] || die "arquivo obrigatorio ausente: ${file}"
}

has_fixed_string() {
  local needle="$1"
  local file="$2"
  rg -q --fixed-strings "$needle" "$file"
}

append_line() {
  MANIFEST_LINES+=("$1")
}

append_hash_lines() {
  local kind="$1"
  shift

  local file hash
  for file in "$@"; do
    require_file "$file"
    hash="$(sha256sum "$file" | awk '{print $1}')"
    append_line "${kind}|sha256|${file}|${hash}"
  done
}

while (( $# > 0 )); do
  case "$1" in
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

readonly PLYMOUTH_MODULE="themes/plymouth/plymouth.nix"
readonly PLYMOUTH_PACKAGE="themes/plymouth/ragos/default.nix"
readonly PLYMOUTH_THEME="themes/plymouth/ragos/ragos.plymouth"
readonly PLYMOUTH_SCRIPT="themes/plymouth/ragos/ragos.script"
readonly SDDM_MODULE="themes/sddm/sddm.nix"
readonly SDDM_PACKAGE="themes/sddm/ragos-control/default.nix"
readonly SDDM_MAIN="themes/sddm/ragos-control/Main.qml"
readonly SDDM_ACTION_BUTTON="themes/sddm/ragos-control/Components/ActionButton.qml"
readonly SDDM_INFO_CHIP="themes/sddm/ragos-control/Components/InfoChip.qml"
readonly SDDM_THEME_CONF="themes/sddm/ragos-control/theme.conf.in"
readonly SDDM_METADATA="themes/sddm/ragos-control/metadata.desktop"
readonly FLAKE_ROOT="flake.nix"
readonly FLAKE_DEFAULT_PARAMS="flake/default-params.nix"
readonly FLAKE_LIB="flake/lib.nix"
readonly FLAKE_BRANDING_ASSETS="flake/branding-assets.nix"
readonly FLAKE_PACKAGES="flake/packages.nix"
readonly PLASMA_BRANDING="client/desktop/branding.nix"
readonly PLASMA_GENERIC="client/desktop/plasma-generic.nix"
readonly PLASMA_LAB="client/desktop/plasma-lab.nix"
readonly PLASMA_PACKAGE="themes/plasma/default.nix"
readonly PLASMA_LAF_DARK="themes/plasma/look-and-feel/org.ragos.desktop.dark/metadata.json"
readonly PLASMA_LAF_LIGHT="themes/plasma/look-and-feel/org.ragos.desktop.light/metadata.json"
readonly PLASMA_STYLE_DARK="themes/plasma/plasma-style/ragos-dark/metadata.json"
readonly PLASMA_STYLE_LIGHT="themes/plasma/plasma-style/ragos-light/metadata.json"
readonly PLASMA_COLOR_DARK="themes/plasma/colors/RAGOSDark.colors"
readonly PLASMA_COLOR_LIGHT="themes/plasma/colors/RAGOSLight.colors"
readonly PLASMA_WALLPAPER_DARK_META="themes/plasma/wallpapers/org.ragos.wallpaper.dark/metadata.json"
readonly PLASMA_WALLPAPER_LIGHT_META="themes/plasma/wallpapers/org.ragos.wallpaper.light/metadata.json"
readonly PLASMA_WALLPAPER_SLIDE_1="themes/wallpapers/plasma-slide-moonlake-night.png"
readonly PLASMA_WALLPAPER_SLIDE_2="themes/wallpapers/plasma-slide-retro-stars.png"
readonly PLASMA_WALLPAPER_SLIDE_3="themes/wallpapers/plasma-slide-valley-day.png"
readonly CLI_FILE="server/ragos-cli.nix"

for required in \
  "$PLYMOUTH_MODULE" \
  "$PLYMOUTH_PACKAGE" \
  "$PLYMOUTH_THEME" \
  "$PLYMOUTH_SCRIPT" \
  "$SDDM_MODULE" \
  "$SDDM_PACKAGE" \
  "$SDDM_MAIN" \
  "$SDDM_ACTION_BUTTON" \
  "$SDDM_INFO_CHIP" \
  "$SDDM_THEME_CONF" \
  "$SDDM_METADATA" \
  "$FLAKE_ROOT" \
  "$FLAKE_DEFAULT_PARAMS" \
  "$FLAKE_LIB" \
  "$FLAKE_BRANDING_ASSETS" \
  "$FLAKE_PACKAGES" \
  "$PLASMA_BRANDING" \
  "$PLASMA_GENERIC" \
  "$PLASMA_LAB" \
  "$PLASMA_PACKAGE" \
  "$PLASMA_LAF_DARK" \
  "$PLASMA_LAF_LIGHT" \
  "$PLASMA_STYLE_DARK" \
  "$PLASMA_STYLE_LIGHT" \
  "$PLASMA_COLOR_DARK" \
  "$PLASMA_COLOR_LIGHT" \
  "$PLASMA_WALLPAPER_DARK_META" \
  "$PLASMA_WALLPAPER_LIGHT_META" \
  "$PLASMA_WALLPAPER_SLIDE_1" \
  "$PLASMA_WALLPAPER_SLIDE_2" \
  "$PLASMA_WALLPAPER_SLIDE_3" \
  "$CLI_FILE"; do
  require_file "$required"
done

declare -a MANIFEST_LINES=()

append_line "brandlab_manifest_version|2"

if has_fixed_string 'theme = "ragos";' "$PLYMOUTH_MODULE"; then
  append_line "surface|plymouth|declarative-theme|present|${PLYMOUTH_MODULE}|theme=ragos"
else
  append_line "surface|plymouth|declarative-theme|missing|${PLYMOUTH_MODULE}|theme=ragos"
fi

if has_fixed_string 'theme = "ragos-control";' "$SDDM_MODULE"; then
  append_line "surface|sddm|declarative-theme|present|${SDDM_MODULE}|theme=ragos-control"
else
  append_line "surface|sddm|declarative-theme|missing|${SDDM_MODULE}|theme=ragos-control"
fi

if has_fixed_string './branding.nix' "$PLASMA_GENERIC"; then
  append_line "surface|plasma|desktop-generic-import|present|${PLASMA_GENERIC}|imports=branding.nix"
else
  append_line "surface|plasma|desktop-generic-import|missing|${PLASMA_GENERIC}|imports=branding.nix"
fi

if has_fixed_string './branding.nix' "$PLASMA_LAB"; then
  append_line "surface|plasma|desktop-lab-import|present|${PLASMA_LAB}|imports=branding.nix"
else
  append_line "surface|plasma|desktop-lab-import|missing|${PLASMA_LAB}|imports=branding.nix"
fi

if has_fixed_string 'ragosPlasmaBranding' "$PLASMA_PACKAGE"; then
  append_line "surface|plasma|package|present|${PLASMA_PACKAGE}|ragosPlasmaBranding"
else
  append_line "surface|plasma|package|missing|${PLASMA_PACKAGE}|ragosPlasmaBranding"
fi

if has_fixed_string '"ragos-plasma-theme"' "$FLAKE_PACKAGES"; then
  append_line "surface|plasma|flake-package|present|${FLAKE_PACKAGES}|ragos-plasma-theme"
else
  append_line "surface|plasma|flake-package|missing|${FLAKE_PACKAGES}|ragos-plasma-theme"
fi

if has_fixed_string '"ragos-plasma-kde-store-bundles"' "$FLAKE_PACKAGES"; then
  append_line "surface|plasma|kde-store-bundles|present|${FLAKE_PACKAGES}|ragos-plasma-kde-store-bundles"
else
  append_line "surface|plasma|kde-store-bundles|missing|${FLAKE_PACKAGES}|ragos-plasma-kde-store-bundles"
fi

if has_fixed_string 'brandingAssets = import ./branding-assets.nix;' "$FLAKE_DEFAULT_PARAMS"; then
  append_line "surface|flake|default-branding-assets|present|${FLAKE_DEFAULT_PARAMS}|brandingAssets"
else
  append_line "surface|flake|default-branding-assets|missing|${FLAKE_DEFAULT_PARAMS}|brandingAssets"
fi

if has_fixed_string 'ragosBrandingAssets = brandingAssets;' "$FLAKE_LIB"; then
  append_line "surface|flake|specialargs-branding-assets|present|${FLAKE_LIB}|ragosBrandingAssets"
else
  append_line "surface|flake|specialargs-branding-assets|missing|${FLAKE_LIB}|ragosBrandingAssets"
fi

if has_fixed_string 'ragosBrandingAssets = genericBrandingAssets;' "$FLAKE_ROOT"; then
  append_line "surface|flake|top-level-branding-assets|present|${FLAKE_ROOT}|ragosBrandingAssets"
else
  append_line "surface|flake|top-level-branding-assets|missing|${FLAKE_ROOT}|ragosBrandingAssets"
fi

if has_fixed_string 'plasma-slide-moonlake-night.png' "$FLAKE_BRANDING_ASSETS"; then
  append_line "surface|plasma|asset-registry|present|${FLAKE_BRANDING_ASSETS}|canonical-wallpaper-assets"
else
  append_line "surface|plasma|asset-registry|missing|${FLAKE_BRANDING_ASSETS}|canonical-wallpaper-assets"
fi

if has_fixed_string '"Id": "org.ragos.desktop.dark"' "$PLASMA_LAF_DARK"; then
  append_line "surface|plasma|look-and-feel-dark|present|${PLASMA_LAF_DARK}|org.ragos.desktop.dark"
else
  append_line "surface|plasma|look-and-feel-dark|missing|${PLASMA_LAF_DARK}|org.ragos.desktop.dark"
fi

if has_fixed_string '"Id": "org.ragos.desktop.light"' "$PLASMA_LAF_LIGHT"; then
  append_line "surface|plasma|look-and-feel-light|present|${PLASMA_LAF_LIGHT}|org.ragos.desktop.light"
else
  append_line "surface|plasma|look-and-feel-light|missing|${PLASMA_LAF_LIGHT}|org.ragos.desktop.light"
fi

if has_fixed_string '"Id": "ragos-dark"' "$PLASMA_STYLE_DARK"; then
  append_line "surface|plasma|desktoptheme-dark|present|${PLASMA_STYLE_DARK}|ragos-dark"
else
  append_line "surface|plasma|desktoptheme-dark|missing|${PLASMA_STYLE_DARK}|ragos-dark"
fi

if has_fixed_string '"Id": "ragos-light"' "$PLASMA_STYLE_LIGHT"; then
  append_line "surface|plasma|desktoptheme-light|present|${PLASMA_STYLE_LIGHT}|ragos-light"
else
  append_line "surface|plasma|desktoptheme-light|missing|${PLASMA_STYLE_LIGHT}|ragos-light"
fi

if has_fixed_string 'ColorScheme=RAGOSDark' "$PLASMA_COLOR_DARK"; then
  append_line "surface|plasma|colorscheme-dark|present|${PLASMA_COLOR_DARK}|RAGOSDark"
else
  append_line "surface|plasma|colorscheme-dark|missing|${PLASMA_COLOR_DARK}|RAGOSDark"
fi

if has_fixed_string 'ColorScheme=RAGOSLight' "$PLASMA_COLOR_LIGHT"; then
  append_line "surface|plasma|colorscheme-light|present|${PLASMA_COLOR_LIGHT}|RAGOSLight"
else
  append_line "surface|plasma|colorscheme-light|missing|${PLASMA_COLOR_LIGHT}|RAGOSLight"
fi

if has_fixed_string '"Id": "org.ragos.wallpaper.dark"' "$PLASMA_WALLPAPER_DARK_META"; then
  append_line "surface|plasma|wallpaper-dark|present|${PLASMA_WALLPAPER_DARK_META}|org.ragos.wallpaper.dark"
else
  append_line "surface|plasma|wallpaper-dark|missing|${PLASMA_WALLPAPER_DARK_META}|org.ragos.wallpaper.dark"
fi

if has_fixed_string '"Id": "org.ragos.wallpaper.light"' "$PLASMA_WALLPAPER_LIGHT_META"; then
  append_line "surface|plasma|wallpaper-light|present|${PLASMA_WALLPAPER_LIGHT_META}|org.ragos.wallpaper.light"
else
  append_line "surface|plasma|wallpaper-light|missing|${PLASMA_WALLPAPER_LIGHT_META}|org.ragos.wallpaper.light"
fi

if has_fixed_string 'plasma-apply-lookandfeel' "$PLASMA_BRANDING"; then
  append_line "surface|plasma|lookandfeel-apply|present|${PLASMA_BRANDING}|plasma-apply-lookandfeel"
else
  append_line "surface|plasma|lookandfeel-apply|missing|${PLASMA_BRANDING}|plasma-apply-lookandfeel"
fi

if has_fixed_string 'plasma-proof.env' "$PLASMA_BRANDING"; then
  append_line "surface|plasma|variant-proof|present|${PLASMA_BRANDING}|plasma-proof.env"
else
  append_line "surface|plasma|variant-proof|missing|${PLASMA_BRANDING}|plasma-proof.env"
fi

if has_fixed_string 'cmd_branding_doctor()' "$CLI_FILE"; then
  append_line "surface|runtime|doctor|present|${CLI_FILE}|ragos branding doctor"
else
  append_line "surface|runtime|doctor|missing|${CLI_FILE}|ragos branding doctor"
fi

if rg -n --glob '*.nix' --glob '*.conf' --glob '*.ini' '\bgtk\b' client themes >/dev/null 2>&1; then
  append_line "surface|gtk|custom-theme|present|repo-scan|explicit-gtk-references-found"
else
  append_line "surface|gtk|custom-theme|absent|repo-scan|no-explicit-gtk-theme"
fi

append_hash_lines config \
  "$PLYMOUTH_MODULE" \
  "$PLYMOUTH_PACKAGE" \
  "$PLYMOUTH_THEME" \
  "$PLYMOUTH_SCRIPT" \
  "$SDDM_MODULE" \
  "$SDDM_PACKAGE" \
  "$SDDM_MAIN" \
  "$SDDM_ACTION_BUTTON" \
  "$SDDM_INFO_CHIP" \
  "$SDDM_THEME_CONF" \
  "$SDDM_METADATA" \
  "$FLAKE_ROOT" \
  "$FLAKE_DEFAULT_PARAMS" \
  "$FLAKE_LIB" \
  "$FLAKE_BRANDING_ASSETS" \
  "$FLAKE_PACKAGES" \
  "$PLASMA_BRANDING" \
  "$PLASMA_GENERIC" \
  "$PLASMA_LAB" \
  "$PLASMA_PACKAGE" \
  "$PLASMA_LAF_DARK" \
  "$PLASMA_LAF_LIGHT" \
  "$PLASMA_STYLE_DARK" \
  "$PLASMA_STYLE_LIGHT" \
  "$PLASMA_COLOR_DARK" \
  "$PLASMA_COLOR_LIGHT" \
  "$PLASMA_WALLPAPER_DARK_META" \
  "$PLASMA_WALLPAPER_LIGHT_META"

append_hash_lines asset \
  "themes/plymouth/ragos/background.jpg" \
  "themes/plymouth/ragos/logo.png" \
  "themes/plymouth/ragos/progress-fill.png" \
  "themes/plymouth/ragos/progress-track.png" \
  "themes/plymouth/ragos/source-background.jpg" \
  "themes/grub/ragos/background.png" \
  "themes/wallpapers/ragos-logo-terminal.png" \
  "$PLASMA_WALLPAPER_SLIDE_1" \
  "$PLASMA_WALLPAPER_SLIDE_2" \
  "$PLASMA_WALLPAPER_SLIDE_3"

manifest_output="$(printf '%s\n' "${MANIFEST_LINES[@]}")"

if [[ -n "$OUTPUT_PATH" ]]; then
  mkdir -p "$(dirname "$OUTPUT_PATH")"
  printf '%s\n' "$manifest_output" >"$OUTPUT_PATH"
else
  printf '%s\n' "$manifest_output"
fi
