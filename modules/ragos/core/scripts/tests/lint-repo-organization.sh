#!/usr/bin/env bash
# Purpose: Validar convencoes organizacionais e fontes de verdade do repositorio
# Category: tests
# Safety: safe
# Expected environment: checkout local do RAGOS ou app Nix com git e rg disponiveis
# Requires: bash, git, rg
# Notes: Lint estrutural; nao substitui flake check nem testes funcionais

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

failures=0

section() {
  printf '\n[%s]\n' "$1"
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

check_commands() {
  local cmd
  for cmd in git rg; do
    command -v "$cmd" >/dev/null 2>&1 || {
      printf 'ERROR: comando obrigatorio ausente: %s\n' "$cmd" >&2
      printf 'Dica: execute via `nix run .#repo-hygiene-lint` ou inclua a dependencia no ambiente Nix/CI.\n' >&2
      exit 2
    }
  done
}

trim_line() {
  sed -n "s/^$1: //p" "$2" | head -n 1 | xargs
}

check_root_markdown() {
  section "root-markdown"

  local file
  while IFS= read -r file; do
    case "$file" in
      README.md|CHANGELOG.md|CONTRIBUTING.md|INSTRUCOES.md|INSTRUCT.md)
        ;;
      *)
        fail "markdown no topo do repo fora da allowlist: $file"
        ;;
    esac
  done < <(find . -maxdepth 1 -type f -name '*.md' -printf '%P\n' | sort)
}

check_root_legacy_paths() {
  section "root-legacy"

  local dir
  for dir in ragos SRV-RAGOS; do
    [[ -e "$dir" ]] && fail "arvore legada reintroduzida na raiz: $dir"
  done

  while IFS= read -r dir; do
    fail "asset vendorizado fora do dominio canonico themes/: $dir"
  done < <(find . -maxdepth 1 -mindepth 1 -type d -name 'DepartureMono-*' -printf '%P\n' | sort)
}

check_docs_layout() {
  section "docs-layout"

  local dir
  while IFS= read -r dir; do
    fail "subdiretorio inesperado em docs/: $dir"
  done < <(find docs -mindepth 1 -maxdepth 1 -type d ! -name archive -printf '%P\n' | sort)
}

check_docs_headers() {
  section "docs-headers"

  local file status

  while IFS= read -r file; do
    rg -q '^Status: ' "$file" || fail "doc sem Status: $file"
    rg -q '^Scope: ' "$file" || fail "doc sem Scope: $file"
    status="$(trim_line 'Status' "$file")"

    case "$status" in
      canonical|secondary)
        ;;
      *)
        fail "doc em docs/ com Status invalido ($status): $file"
        ;;
    esac

    if [[ "$status" == "canonical" ]]; then
      rg -q '^Last reviewed: [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$file" || fail "doc canonical sem Last reviewed valido: $file"
    fi
  done < <(find docs -maxdepth 1 -type f -name '*.md' | sort)

  while IFS= read -r file; do
    status="$(trim_line 'Status' "$file")"
    [[ "$status" == "archived" ]] || fail "doc em docs/archive sem Status archived: $file"
    rg -q '^Scope: ' "$file" || fail "doc em docs/archive sem Scope: $file"
  done < <(find docs/archive -maxdepth 1 -type f -name '*.md' | sort)
}

check_archive_references() {
  section "archive-references"

  local file
  while IFS= read -r file; do
    if rg -n '(docs/archive/|archive/)' "$file" >/dev/null; then
      fail "doc canonico/secundario referencia archive/: $file"
    fi
  done < <(find docs -maxdepth 1 -type f -name '*.md' ! -name 'README.md' | sort)
}

check_scripts_layout() {
  section "scripts-layout"

  local file dir

  while IFS= read -r file; do
    fail "script solto em scripts/: $file"
  done < <(find scripts -maxdepth 1 -type f ! -name 'README.md' -printf '%P\n' | sort)

  while IFS= read -r dir; do
    fail "subdiretorio inesperado em scripts/: $dir"
  done < <(find scripts -mindepth 1 -maxdepth 1 -type d ! -name dev ! -name ops ! -name tests ! -name lab -printf '%P\n' | sort)
}

check_script_headers() {
  section "script-headers"

  local file category
  while IFS= read -r file; do
    category="$(basename "$(dirname "$file")")"
    rg -q '^# Purpose: ' "$file" || fail "script sem Purpose: $file"
    rg -q "^# Category: $category$" "$file" || fail "script com Category divergente do diretorio: $file"
    rg -q '^# Safety: (safe|destructive|lab-only)$' "$file" || fail "script sem Safety valido: $file"
  done < <(find scripts/dev scripts/ops scripts/tests scripts/lab -type f | sort)
}

check_banned_references() {
  section "banned-references"

  local -a files=(
    "README.md"
    "CONTRIBUTING.md"
    "scripts/README.md"
  )

  while IFS= read -r file; do
    files+=("$file")
  done < <(find docs -maxdepth 1 -type f -name '*.md' | sort)

  local -a patterns=(
    'docs/clients-inventory\.csv'
    'flake/client\.nix'
    'flake/server\.nix'
    'flake/installer\.nix'
    'server/server\.nix'
    'installer/installer\.nix'
    'ragos/pxe/'
    'ragos/scripts/provision-tftp\.sh'
    '\./scripts/migrate-ragos-inventory\.sh'
    '\./scripts/test-clients-inventory-validation\.sh'
    '\./scripts/test-ragc-phaseA\.sh'
  )

  local pattern file
  for pattern in "${patterns[@]}"; do
    for file in "${files[@]}"; do
      [[ -f "$file" ]] || continue
      if rg -n "$pattern" "$file" >/dev/null; then
        fail "referencia antiga ou removida em $file: $pattern"
      fi
    done
  done
}

check_inventory_rules() {
  section "inventory-rules"

  local file

  while IFS= read -r file; do
    fail "CSV de inventario reintroduzido no repo: $file"
  done < <(find . \
    -path './.git' -prune -o \
    -path './docs/archive' -prune -o \
    -type f \( -name 'clients-inventory.csv' -o -name 'clients.csv' \) -printf '%P\n' | sort)

  while IFS= read -r file; do
    fail "server/ ou flake/ referenciando inventory bootstrap como fonte primaria: $file"
  done < <(rg -l 'clients-inventory\.bootstrap\.nix|clients-inventory\.csv' server flake -g '*.nix' || true)
}

check_artifacts() {
  section "artifacts"

  local file
  while IFS= read -r file; do
    fail "artefato temporario no checkout: $file"
  done < <(find . \
    -path './.git' -prune -o \
    -path './installer/.git' -prune -o \
    \( -name 'result' -o -name 'result-*' -o -name '*.log' -o -name '*.tmp' -o -name '*.bak' -o -name '*~' -o -name 'nohup.out' \) \
    -printf '%P\n' | sort)
}

main() {
  check_commands
  check_root_markdown
  check_root_legacy_paths
  check_docs_layout
  check_docs_headers
  check_archive_references
  check_scripts_layout
  check_script_headers
  check_banned_references
  check_inventory_rules
  check_artifacts

  if (( failures > 0 )); then
    printf '\nRepo organization lint failed with %d issue(s).\n' "$failures" >&2
    exit 1
  fi

  printf '\nRepo organization lint passed.\n'
}

main "$@"
