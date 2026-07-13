#!/usr/bin/env bash
# Purpose: Validar o contrato do BrandLab entre wiring real, baseline e documentacao
# Category: tests
# Safety: safe
# Expected environment: checkout local do RAGOS
# Requires: bash, coreutils, diff, ripgrep

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp_dir="$(mktemp -d)"
tmp_manifest="${tmp_dir}/current-manifest.txt"
tmp_report="${tmp_dir}/current-branding-comparison.md"
tmp_diff="${tmp_dir}/manifest.diff"
tmp_runtime="${tmp_dir}/runtime-branding-doctor.txt"
trap 'rm -rf "$tmp_dir"' EXIT

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  grep -Fq "$needle" <<<"$haystack" || {
    echo "ASSERT FAIL [$label]: missing '$needle'" >&2
    exit 1
  }
}

echo "[1/5] regenerate BrandLab manifest"
bash "$repo_root/scripts/lab/branding/generate-branding-manifest.sh" --output "$tmp_manifest"
diff -u "$repo_root/artifacts/branding/baseline-manifest.txt" "$tmp_manifest"

echo "[2/5] canonical docs describe scope honestly"
branding_doc="$(cat "$repo_root/docs/branding-review.md")"
docs_readme="$(cat "$repo_root/docs/README.md")"
themes_readme="$(cat "$repo_root/themes/README.md")"
scripts_readme="$(cat "$repo_root/scripts/README.md")"
assert_contains "$branding_doc" "GTK nao possui tema declarativo proprio no estado atual do repositorio." "gtk honesty"
assert_contains "$branding_doc" '`ragos branding doctor`' "runtime doctor"
assert_contains "$branding_doc" "Nenhuma conclusao visual deve ser declarada como sucesso sem screenshot real ou checklist preenchido." "anti hallucination"
assert_contains "$branding_doc" "Global Themes" "plasma global themes"
assert_contains "$branding_doc" '`ragos-plasma-report`' "plasma proof command"
assert_contains "$docs_readme" "branding-review.md" "docs index"
assert_contains "$themes_readme" '`plasma/`' "themes plasma index"
assert_contains "$scripts_readme" "test-brandlab-contract.sh" "scripts readme test listing"
assert_contains "$scripts_readme" "lab/branding/generate-branding-manifest.sh" "scripts readme lab manifest"
assert_contains "$scripts_readme" "lab/branding/compare-branding-baseline.sh" "scripts readme compare script"
assert_contains "$scripts_readme" "lab/branding/set-plasma-variant.sh" "scripts readme plasma variant"
assert_contains "$scripts_readme" "lab/branding/prove-plasma-theme.sh" "scripts readme plasma proof"

echo "[3/5] BrandLab scripts and artifact entrypoints exist"
[[ -f "$repo_root/scripts/lab/branding/capture-plasma.sh" ]] || { echo "ASSERT FAIL [capture plasma script]: missing file" >&2; exit 1; }
[[ -f "$repo_root/scripts/lab/branding/capture-sddm.sh" ]] || { echo "ASSERT FAIL [capture sddm script]: missing file" >&2; exit 1; }
[[ -f "$repo_root/scripts/lab/branding/capture-plymouth.sh" ]] || { echo "ASSERT FAIL [capture plymouth script]: missing file" >&2; exit 1; }
[[ -f "$repo_root/scripts/lab/branding/capture-branding-e2e.sh" ]] || { echo "ASSERT FAIL [capture e2e script]: missing file" >&2; exit 1; }
[[ -f "$repo_root/scripts/lab/branding/compare-branding-baseline.sh" ]] || { echo "ASSERT FAIL [compare script]: missing file" >&2; exit 1; }
[[ -f "$repo_root/scripts/lab/branding/set-plasma-variant.sh" ]] || { echo "ASSERT FAIL [set plasma variant script]: missing file" >&2; exit 1; }
[[ -f "$repo_root/scripts/lab/branding/prove-plasma-theme.sh" ]] || { echo "ASSERT FAIL [prove plasma theme script]: missing file" >&2; exit 1; }
[[ -f "$repo_root/artifacts/branding/README.md" ]] || { echo "ASSERT FAIL [artifacts readme]: missing file" >&2; exit 1; }
[[ -f "$repo_root/artifacts/branding/screenshots/README.md" ]] || { echo "ASSERT FAIL [screenshots readme]: missing file" >&2; exit 1; }
[[ -f "$repo_root/artifacts/branding/reports/README.md" ]] || { echo "ASSERT FAIL [reports readme]: missing file" >&2; exit 1; }

echo "[4/5] baseline encodes current declarative state"
baseline_manifest="$(cat "$repo_root/artifacts/branding/baseline-manifest.txt")"
assert_contains "$baseline_manifest" "surface|gtk|custom-theme|absent|repo-scan|no-explicit-gtk-theme" "gtk baseline state"
assert_contains "$baseline_manifest" "surface|sddm|declarative-theme|present|themes/sddm/sddm.nix|theme=ragos-control" "sddm baseline theme"
assert_contains "$baseline_manifest" "surface|plasma|look-and-feel-dark|present|themes/plasma/look-and-feel/org.ragos.desktop.dark/metadata.json|org.ragos.desktop.dark" "plasma dark look and feel"
assert_contains "$baseline_manifest" "surface|plasma|desktoptheme-light|present|themes/plasma/plasma-style/ragos-light/metadata.json|ragos-light" "plasma light style"
assert_contains "$baseline_manifest" "surface|plasma|flake-package|present|flake/packages.nix|ragos-plasma-theme" "flake plasma package"

echo "[5/5] comparison report works even when screenshots are absent"
bash "$repo_root/scripts/lab/branding/compare-branding-baseline.sh" \
  --current "$tmp_manifest" \
  --screenshots-dir "$tmp_dir/empty-screenshots" \
  --output "$tmp_report" \
  --diff-output "$tmp_diff" \
  --runtime-output "$tmp_runtime" \
  --runtime-mode skip
comparison_report="$(cat "$tmp_report")"
assert_contains "$comparison_report" "BrandLab Comparative Review" "comparison report title"
assert_contains "$comparison_report" "runtime_branding_doctor: skipped" "comparison runtime skip"
assert_contains "$comparison_report" "[MISSING] Plymouth: sem captura atual." "comparison missing plymouth"
assert_contains "$comparison_report" "[MISSING] SDDM: sem captura atual." "comparison missing sddm"
assert_contains "$comparison_report" "[MISSING] Plasma: sem captura atual." "comparison missing plasma"

echo "BrandLab contract harness passed."
