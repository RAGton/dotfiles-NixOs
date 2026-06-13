kryonix_git_repo_path() {
  if [[ -n "${KRYONIX_SYSTEM_REPO:-}" ]]; then
    printf '%s\n' "$KRYONIX_SYSTEM_REPO"
    return 0
  fi

  printf '%s\n' "/etc/kryonix"
}

# Detecção do papel do diretório atual (ver
# docs/operations/GIT_DEV_PROD_WORKFLOW.md). Imprime um dos rótulos:
#   DEV-MOTOR | DEV-SITE | PROD-MOTOR | PROD-SITE | UNKNOWN
kryonix_detect_env() {
  local target="${1:-$PWD}"

  case "$target" in
    /home/rocha/kryonix/kryonix|/home/rocha/kryonix/kryonix/*)     printf '%s\n' "DEV-MOTOR" ;;
    /home/rocha/kryonix/kryonixos|/home/rocha/kryonix/kryonixos/*) printf '%s\n' "DEV-SITE" ;;
    /etc/kryonix|/etc/kryonix/*)                                   printf '%s\n' "PROD-MOTOR" ;;
    /etc/kryonixos|/etc/kryonixos/*)                               printf '%s\n' "PROD-SITE" ;;
    *)                                                             printf '%s\n' "UNKNOWN" ;;
  esac
}

# Verdade quando o ambiente detectado for PROD-*.
kryonix_env_is_prod() {
  local env="${1:-$(kryonix_detect_env)}"
  [[ "$env" == "PROD-MOTOR" || "$env" == "PROD-SITE" ]]
}

# Verdade quando o ambiente detectado for DEV-*.
kryonix_env_is_dev() {
  local env="${1:-$(kryonix_detect_env)}"
  [[ "$env" == "DEV-MOTOR" || "$env" == "DEV-SITE" ]]
}

kryonix_env_policy() {
  local env="$1"
  local key="$2"

  case "${env}:${key}" in
    DEV-MOTOR:edits_allowed|DEV-MOTOR:flake_update_allowed|DEV-MOTOR:push_allowed) printf '%s\n' "yes" ;;
    DEV-MOTOR:switch_allowed)                                                     printf '%s\n' "no" ;;
    DEV-SITE:edits_allowed|DEV-SITE:push_allowed)                                  printf '%s\n' "yes" ;;
    DEV-SITE:flake_update_allowed|DEV-SITE:switch_allowed)                         printf '%s\n' "n/a" ;;
    PROD-MOTOR:edits_allowed|PROD-MOTOR:flake_update_allowed|PROD-MOTOR:push_allowed) printf '%s\n' "no" ;;
    PROD-MOTOR:switch_allowed)                                                    printf '%s\n' "yes (com check+diff+test)" ;;
    PROD-SITE:edits_allowed|PROD-SITE:push_allowed)                                printf '%s\n' "no" ;;
    PROD-SITE:flake_update_allowed|PROD-SITE:switch_allowed)                       printf '%s\n' "n/a" ;;
    *)                                                                              printf '%s\n' "unknown" ;;
  esac
}

is_git_repo() {
  local repo_path="$1"

  git -C "$repo_path" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

git_current_branch() {
  local repo_path="$1"

  git -C "$repo_path" branch --show-current 2>/dev/null || true
}

git_origin_url() {
  local repo_path="$1"

  git -C "$repo_path" remote get-url origin 2>/dev/null || true
}

git_short_changes() {
  local repo_path="$1"

  git -C "$repo_path" status --short 2>/dev/null || true
}

git_has_conflict_state() {
  local repo_path="$1"
  local git_dir

  git_dir="$(git -C "$repo_path" rev-parse --absolute-git-dir 2>/dev/null || true)"
  [[ -n "$git_dir" ]] || return 1

  [[ -d "$git_dir/rebase-merge" ]] \
    || [[ -d "$git_dir/rebase-apply" ]] \
    || [[ -f "$git_dir/MERGE_HEAD" ]] \
    || [[ -f "$git_dir/CHERRY_PICK_HEAD" ]]
}

git_has_tracked_changes() {
  local repo_path="$1"

  ! git -C "$repo_path" diff --quiet --no-ext-diff --cached \
    || ! git -C "$repo_path" diff --quiet --no-ext-diff
}

ensure_kryonix_git_state() {
  local repo_path="$1"
  local branch
  local origin

  if ! is_git_repo "$repo_path"; then
    printf '%s\n' "ERRO: $repo_path não é um git repo válido." >&2
    return 1
  fi

  branch="$(git_current_branch "$repo_path")"
  origin="$(git_origin_url "$repo_path")"

  if [[ -z "$origin" ]]; then
    printf '%s\n' "ERRO: $repo_path não possui remote origin configurado." >&2
    return 1
  fi

  if [[ "$branch" != "main" ]]; then
    printf '%s\n' "ERRO: branch activa '$branch' inválida; esperado 'main'." >&2
    return 1
  fi

  if git_has_conflict_state "$repo_path"; then
    printf '%s\n' "ERRO: $repo_path já está com merge/rebase em andamento." >&2
    return 1
  fi
}

kryonix_pull_repo() {
  local repo_path
  repo_path="$(kryonix_git_repo_path)"

  ensure_kryonix_git_state "$repo_path" || return 1

  if git_has_tracked_changes "$repo_path"; then
    printf '%s\n' "ERRO: $repo_path possui mudanças locais versionadas; revise com 'kryonix git-status' antes de puxar." >&2
    return 1
  fi

  run_command git -C "$repo_path" fetch --all --prune --tags
  if ! run_command git -C "$repo_path" pull --ff-only origin main; then
     printf '%s\n' "ERRO: git pull --ff-only falhou em $repo_path." >&2
     printf '%s\n' "       Possivel divergencia local. Decisao humana necessaria;" >&2
     printf '%s\n' "       nao use 'git reset --hard' nem 'git pull --rebase' aqui." >&2
     return 1
  fi

  run_command git -C "$repo_path" submodule update --init --recursive
}

kryonix_deploy_repo() {
  local repo_path
  repo_path="$(kryonix_git_repo_path)"

  ensure_kryonix_git_state "$repo_path" || return 1

  # Validação antes do deploy
  run_command nix flake check "$repo_path" --keep-going || {
    printf '%s\n' "ERRO: falha na validação da flake em $repo_path." >&2
    return 1
  }

  cmd=(nh os switch "$repo_path" -H "$flake_host")
  cmd+=("${verbose_args[@]}" "${dry_args[@]}" "${extra_args[@]}")
  run_command "${cmd[@]}"
}

kryonix_sync_repo() {
  kryonix_pull_repo || return 1
  kryonix_deploy_repo
}

print_git_changes() {
  local repo_path="$1"
  local changes

  changes="$(git_short_changes "$repo_path")"
  if [[ -z "$changes" ]]; then
    blue_line '  mudanças locais : nenhuma'
    return 0
  fi

  blue_line '  mudanças locais :'
  printf '%s\n' "$changes"
}

print_kryonix_git_status() {
  local repo_path repo_root branch origin

  repo_path="$(kryonix_git_repo_path)"
  blue_line 'Kryonix git-status'
  blue_line "  path            : $repo_path"
  if [[ -L "$repo_path" ]]; then
    blue_line "  symlink         : $(readlink "$repo_path")"
  fi

  if ! is_git_repo "$repo_path"; then
    blue_line '  status          : ERRO'
    printf '%s\n' "ERRO: $repo_path não é um git repo válido." >&2
    return 1
  fi

  repo_root="$(git -C "$repo_path" rev-parse --show-toplevel)"
  branch="$(git_current_branch "$repo_path")"
  origin="$(git_origin_url "$repo_path")"
  blue_line "  repo root       : $repo_root"
  blue_line "  branch          : ${branch:-desconhecida}"
  blue_line "  remoto origin   : ${origin:-ausente}"

  if [[ "$branch" != "main" ]]; then
    blue_line '  ATENÇÃO         : branch ativa não é main'
  fi
  if [[ -z "$origin" ]]; then
    blue_line '  ATENÇÃO         : remote origin ausente'
  fi

  print_git_changes "$repo_path"
  [[ "$branch" == "main" && -n "$origin" ]]
}

kryonix_repo_root() {
  local git_root

  if [[ -n "$flake_workdir" ]]; then
    printf '%s\n' "$flake_workdir"
    return 0
  fi

  if git_root="$(find_git_root)" && is_kryonix_checkout "$git_root"; then
    printf '%s\n' "$git_root"
    return 0
  fi

  if is_kryonix_checkout /etc/kryonix; then
    printf '%s\n' /etc/kryonix
    return 0
  fi

  printf '%s\n' "kryonix: não encontrei checkout Kryonix com packages/kryonix-brain-lightrag." >&2
  return 1
}

# Imprime o estado de ambiente DEV/PROD para o repo atual.
# Usado por `kryonix env status` (registry/main).
print_kryonix_env_status() {
  local env repo branch upstream dirty ahead behind

  env="$(kryonix_detect_env)"
  repo="$(git rev-parse --show-toplevel 2>/dev/null || printf '%s' "$PWD")"
  branch="$(git -C "$repo" branch --show-current 2>/dev/null || true)"
  upstream="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"

  if [[ -n "$(git -C "$repo" status --porcelain 2>/dev/null)" ]]; then
    dirty="yes"
  else
    dirty="no"
  fi

  ahead="?"
  behind="?"
  if [[ -n "$upstream" ]]; then
    local counts
    if counts="$(git -C "$repo" rev-list --left-right --count "${upstream}...HEAD" 2>/dev/null)"; then
      behind="$(printf '%s' "$counts" | awk '{print $1}')"
      ahead="$(printf '%s' "$counts" | awk '{print $2}')"
    fi
  fi

  blue_line 'Kryonix env status'
  blue_line "  Environment    : $env"
  blue_line "  Repo           : $repo"
  blue_line "  Branch         : ${branch:-desconhecida}"
  blue_line "  Upstream       : ${upstream:-ausente}"
  blue_line "  Dirty          : $dirty"
  blue_line "  Remote ahead   : $ahead"
  blue_line "  Remote behind  : $behind"
  blue_line '  Policy:'
  blue_line "    edits_allowed        : $(kryonix_env_policy "$env" edits_allowed)"
  blue_line "    flake_update_allowed : $(kryonix_env_policy "$env" flake_update_allowed)"
  blue_line "    push_allowed         : $(kryonix_env_policy "$env" push_allowed)"
  blue_line "    switch_allowed       : $(kryonix_env_policy "$env" switch_allowed)"

  case "$env" in
    PROD-*)
      blue_line '  Lembrete       : PROD nao roda nix flake update. Use git pull --ff-only.'
      ;;
    DEV-*)
      blue_line '  Lembrete       : DEV e a unica area normal de alteracao. Use --ff-only no pull.'
      ;;
    UNKNOWN)
      blue_line '  ATENCAO        : ambiente nao reconhecido. Confirme antes de qualquer acao.'
      ;;
  esac

  [[ "$env" != "UNKNOWN" ]]
}
