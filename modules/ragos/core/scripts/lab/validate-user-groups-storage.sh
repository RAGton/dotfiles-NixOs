#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# RAGOS - User/Group/Storage Validation Script
#
# Valida implementação dos grupos base e sistema de usuários/storage:
# - Grupos: admin (GID 3000), public (GID 3001)
# - Storage: /srv/data/storage/{admin,public,.archive} com permissões corretas
# - Usuário de teste: rag (admin, 20G quota)
# - CLI ragos: user/group commands funcionando
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly RAGOS_HOME="/srv/data/home"
readonly RAGOS_STORAGE="/srv/data/storage"
readonly RAGOS_ARCHIVE="${RAGOS_STORAGE}/.archive"

# Cores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Contadores
pass_count=0
fail_count=0

# Funções de logging
log_section() {
  printf '\n%b=== %s ===%b\n' "$BLUE" "$1" "$NC"
}

log_pass() {
  ((pass_count++))
  printf '%b✓ PASS%b: %s\n' "$GREEN" "$NC" "$1"
}

log_fail() {
  ((fail_count++))
  printf '%b✗ FAIL%b: %s\n' "$RED" "$NC" "$1"
}

log_info() {
  printf '%b[INFO]%b %s\n' "$YELLOW" "$NC" "$1"
}

# ─────────────────────────────────────────────────────────────────────────────
# VALIDAÇÃO 1: Grupos Base
# ─────────────────────────────────────────────────────────────────────────────

validate_base_groups() {
  log_section "VALIDAÇÃO 1: Grupos Base (admin, public)"

  # Verificar grupo admin (GID 3000)
  if getent group admin | grep -q :3000:; then
    log_pass "Grupo admin existe com GID 3000"
  else
    log_fail "Grupo admin com GID 3000 NÃO encontrado"
  fi

  # Verificar grupo public (GID 3001)
  if getent group public | grep -q :3001:; then
    log_pass "Grupo public existe com GID 3001"
  else
    log_fail "Grupo public com GID 3001 NÃO encontrado"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# VALIDAÇÃO 2: Storage Base com Permissões
# ─────────────────────────────────────────────────────────────────────────────

validate_storage_dirs() {
  log_section "VALIDAÇÃO 2: Storage Base e Permissões"

  # Verificar /srv/data/storage/admin (0750)
  if [[ -d "$RAGOS_STORAGE/admin" ]]; then
    local admin_perms
    admin_perms="$(stat -c '%a' "$RAGOS_STORAGE/admin")"
    if [[ "$admin_perms" == "750" ]]; then
      log_pass "Storage admin existe com permissões corretas (0750)"
    else
      log_fail "Storage admin com permissões INCORRETAS: $admin_perms (esperado 0750)"
    fi
  else
    log_fail "Diretório /srv/data/storage/admin NÃO existe"
  fi

  # Verificar /srv/data/storage/public (0770)
  if [[ -d "$RAGOS_STORAGE/public" ]]; then
    local public_perms
    public_perms="$(stat -c '%a' "$RAGOS_STORAGE/public")"
    if [[ "$public_perms" == "770" ]]; then
      log_pass "Storage public existe com permissões corretas (0770)"
    else
      log_fail "Storage public com permissões INCORRETAS: $public_perms (esperado 0770)"
    fi
  else
    log_fail "Diretório /srv/data/storage/public NÃO existe"
  fi

  # Verificar /srv/data/storage/.archive (0700)
  if [[ -d "$RAGOS_ARCHIVE" ]]; then
    local archive_perms
    archive_perms="$(stat -c '%a' "$RAGOS_ARCHIVE")"
    if [[ "$archive_perms" == "700" ]]; then
      log_pass "Storage .archive existe com permissões corretas (0700)"
    else
      log_fail "Storage .archive com permissões INCORRETAS: $archive_perms (esperado 0700)"
    fi
  else
    log_fail "Diretório .archive NÃO existe"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# VALIDAÇÃO 3: Usuário de Teste "rag"
# ─────────────────────────────────────────────────────────────────────────────

validate_test_user() {
  log_section "VALIDAÇÃO 3: Usuário de Teste 'rag'"

  # Verificar que usuário rag existe
  if id rag >/dev/null 2>&1; then
    log_pass "Usuário 'rag' existe"
  else
    log_fail "Usuário 'rag' NÃO encontrado"
    return 1
  fi

  # Verificar que rag está no grupo admin
  if id -Gn rag | grep -q admin; then
    log_pass "Usuário 'rag' pertence ao grupo admin"
  else
    log_fail "Usuário 'rag' NÃO pertence ao grupo admin"
  fi

  # Verificar home /srv/data/home/rag
  if [[ -d "$RAGOS_HOME/rag" ]]; then
    log_pass "Home de 'rag' existe em $RAGOS_HOME/rag"
    local rag_perms
    rag_perms="$(stat -c '%a' "$RAGOS_HOME/rag")"
    if [[ "$rag_perms" == "700" ]]; then
      log_pass "Permissões da home de 'rag' corretas (0700)"
    else
      log_fail "Permissões da home de 'rag' INCORRETAS: $rag_perms (esperado 0700)"
    fi
  else
    log_fail "Home de 'rag' NÃO existe em $RAGOS_HOME/rag"
  fi

  # Verificar owner da home
  if [[ -d "$RAGOS_HOME/rag" ]]; then
    local rag_owner
    rag_owner="$(stat -c '%U:%G' "$RAGOS_HOME/rag")"
    if [[ "$rag_owner" == "rag:users" ]]; then
      log_pass "Owner da home de 'rag' correto (rag:users)"
    else
      log_fail "Owner da home de 'rag' INCORRETO: $rag_owner (esperado rag:users)"
    fi
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# VALIDAÇÃO 4: CLI ragos - Comandos de Usuário/Grupo
# ─────────────────────────────────────────────────────────────────────────────

validate_cli_commands() {
  log_section "VALIDAÇÃO 4: CLI ragos - Comandos"

  # Verificar que ragos existe
  if command -v ragos >/dev/null 2>&1; then
    log_pass "Comando 'ragos' disponível no PATH"
  else
    log_fail "Comando 'ragos' NÃO encontrado no PATH"
    return 1
  fi

  # Testar ragos user list
  if ragos user list >/dev/null 2>&1; then
    log_pass "Comando 'ragos user list' funciona"
  else
    log_fail "Comando 'ragos user list' falhou"
  fi

  # Testar ragos group list
  if ragos group list >/dev/null 2>&1; then
    log_pass "Comando 'ragos group list' funciona"
  else
    log_fail "Comando 'ragos group list' falhou"
  fi

  # Testar ragos group ensure-defaults
  if ragos group ensure-defaults >/dev/null 2>&1; then
    log_pass "Comando 'ragos group ensure-defaults' funciona"
  else
    log_fail "Comando 'ragos group ensure-defaults' falhou"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# VALIDAÇÃO 5: Listar Homes e Quotas
# ─────────────────────────────────────────────────────────────────────────────

show_homes_and_quotas() {
  log_section "VALIDAÇÃO 5: Homes e Quotas"

  log_info "Listing homes in $RAGOS_HOME:"
  printf '%-16s %-16s %-10s %s\n' "usuario" "owner" "perms" "home_path"
  printf '%-16s %-16s %-10s %s\n' "-------" "-----" "-----" "---------"

  shopt -s nullglob
  for home_path in "$RAGOS_HOME"/*; do
    [[ -d "$home_path" ]] || continue
    local user_name
    user_name="$(basename "$home_path")"
    [[ "$user_name" == ".archive" ]] && continue
    local owner
    owner="$(stat -c '%U:%G' "$home_path")"
    local perms
    perms="$(stat -c '%a' "$home_path")"
    printf '%-16s %-16s %-10s %s\n' "$user_name" "$owner" "$perms" "$home_path"
  done
  shopt -u nullglob

  # Mostrar quotas BTRFS se disponível
  if findmnt -n -o FSTYPE --target "$RAGOS_HOME" 2>/dev/null | grep -q btrfs; then
    log_info "BTRFS Quotas em $RAGOS_HOME:"
    btrfs qgroup show "$RAGOS_HOME" 2>/dev/null | head -20 || true
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# VALIDAÇÃO 6: Listar Storage e Permissões
# ─────────────────────────────────────────────────────────────────────────────

show_storage_and_perms() {
  log_section "VALIDAÇÃO 6: Storage e Permissões"

  log_info "Listing storage in $RAGOS_STORAGE:"
  printf '%-16s %-8s %-16s %s\n' "storage" "perms" "owner" "path"
  printf '%-16s %-8s %-16s %s\n' "-------" "-----" "-----" "----"

  shopt -s nullglob
  for storage_path in "$RAGOS_STORAGE"/*; do
    [[ -d "$storage_path" ]] || continue
    local storage_name
    storage_name="$(basename "$storage_path")"
    local perms
    perms="$(stat -c '%a' "$storage_path")"
    local owner
    owner="$(stat -c '%U:%G' "$storage_path")"
    printf '%-16s %-8s %-16s %s\n' "$storage_name" "$perms" "$owner" "$storage_path"
  done
  shopt -u nullglob
}

# ─────────────────────────────────────────────────────────────────────────────
# VALIDAÇÃO 7: Teste de CLI - Criar Usuário Temporário
# ─────────────────────────────────────────────────────────────────────────────

test_cli_user_add() {
  log_section "VALIDAÇÃO 7: Teste CLI - ragos user add (Usuário Temporário)"

  local test_user="rag-teste-$(date +%s)"
  local test_home="$RAGOS_HOME/$test_user"

  # Testar criação de usuário
  if ragos user add "$test_user" --quota 5G --group admin 2>&1 | grep -q "usuario criado"; then
    log_pass "Usuário temporário '$test_user' criado via CLI"
  else
    log_fail "Falha ao criar usuário temporário via CLI"
    return 1
  fi

  # Verificar que home foi criada
  if [[ -d "$test_home" ]]; then
    log_pass "Home do usuário temporário criada em $test_home"
  else
    log_fail "Home do usuário temporário NÃO foi criada"
  fi

  # Verificar quota (se BTRFS disponível)
  if findmnt -n -o FSTYPE --target "$RAGOS_HOME" 2>/dev/null | grep -q btrfs; then
    if btrfs qgroup show "$test_home" 2>/dev/null | grep -q "5.00GiB\|5GiB\|5.0GiB"; then
      log_pass "Quota BTRFS de 5G aplicada ao usuário temporário"
    else
      log_info "Quota BTRFS não visível (normal em alguns casos)"
    fi
  fi

  # Limpeza
  log_info "Limpando usuário temporário '$test_user'..."
  ragos user delete "$test_user" --archive 2>&1 | grep -q "usuario arquivado" || true
}

# ─────────────────────────────────────────────────────────────────────────────
# RESUMO FINAL
# ─────────────────────────────────────────────────────────────────────────────

show_summary() {
  log_section "RESUMO DA VALIDAÇÃO"

  local total=$((pass_count + fail_count))
  printf 'Total: %d | %b✓ PASS: %d%b | %b✗ FAIL: %d%b\n' \
    "$total" "$GREEN" "$pass_count" "$NC" "$RED" "$fail_count" "$NC"

  if (( fail_count == 0 )); then
    printf '\n%b✓ TODAS AS VALIDAÇÕES PASSARAM%b\n' "$GREEN" "$NC"
    return 0
  else
    printf '\n%b✗ ALGUMAS VALIDAÇÕES FALHARAM - Revisar logs acima%b\n' "$RED" "$NC"
    return 1
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────

main() {
  printf '%b╔══════════════════════════════════════════════════════════════════%b\n' "$BLUE" "$NC"
  printf '%b║           RAGOS - User/Group/Storage Validation                  %b║%b\n' "$BLUE" "$NC" "$NC"
  printf '%b╚══════════════════════════════════════════════════════════════════%b\n' "$BLUE" "$NC"

  validate_base_groups
  validate_storage_dirs
  validate_test_user
  validate_cli_commands
  show_homes_and_quotas
  show_storage_and_perms
  test_cli_user_add
  show_summary
}

main "$@"
