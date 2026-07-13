RAGC_LOCK_PATH="${RAGC_LOCK_PATH:-/run/ragc.lock}"
RAGC_LOCK_TIMEOUT="${RAGC_LOCK_TIMEOUT:-60}"
RAGC_LOCK_OWNER_PATH="${RAGC_LOCK_PATH}.owner"
RAGC_LOCK_HELD="${RAGC_LOCK_HELD:-0}"
declare -a __RAGC_EXIT_TRAPS=()

run_exit_traps() {
  local status=$?
  local idx

  for (( idx=${#__RAGC_EXIT_TRAPS[@]}-1; idx>=0; idx-- )); do
    eval "${__RAGC_EXIT_TRAPS[$idx]}" || true
  done

  return "$status"
}

trap_add() {
  __RAGC_EXIT_TRAPS+=("$1")
  trap 'run_exit_traps' EXIT
}

current_commandline() {
  tr '\0' ' ' < "/proc/$$/cmdline" 2>/dev/null | sed 's/[[:space:]]\+$//'
}

release_global_lock() {
  if [[ "${RAGC_LOCK_HELD:-0}" != "1" ]]; then
    return 0
  fi

  rm -f "$RAGC_LOCK_OWNER_PATH"
  flock -u "$RAGC_LOCK_FD" 2>/dev/null || true
  eval "exec ${RAGC_LOCK_FD}>&-"

  unset RAGC_LOCK_FD
  RAGC_LOCK_HELD=0
}

maybe_test_pause() {
  local label="$1"
  local wait_file="${RAGC_TEST_PAUSE_FILE:-}"

  [[ "${RAGC_TEST_PAUSE_AT:-}" == "$label" ]] || return 0

  if [[ -n "$wait_file" ]]; then
    : > "$wait_file"
    while [[ ! -f "${wait_file}.continue" ]]; do
      sleep 0.1
    done
  else
    sleep "${RAGC_TEST_PAUSE_SECONDS:-30}"
  fi
}

acquire_global_lock() {
  if [[ "${RAGC_LOCK_HELD:-0}" == "1" ]]; then
    return 0
  fi

  install -d -m 0755 "$(dirname "$RAGC_LOCK_PATH")"
  exec {RAGC_LOCK_FD}> "$RAGC_LOCK_PATH" || die "Nao foi possivel abrir lock global: $RAGC_LOCK_PATH"

  if ! flock -w "$RAGC_LOCK_TIMEOUT" "$RAGC_LOCK_FD"; then
    local owner="pid=desconhecido command=desconhecido"
    if [[ -s "$RAGC_LOCK_OWNER_PATH" ]]; then
      owner="$(tr '\n' ' ' < "$RAGC_LOCK_OWNER_PATH" | sed 's/[[:space:]]\+$//')"
    fi
    die "Operacao mutante bloqueada por lock global ($RAGC_LOCK_PATH, timeout=${RAGC_LOCK_TIMEOUT}s, owner=$owner)"
  fi

  local owner_tmp="${RAGC_LOCK_OWNER_PATH}.tmp.$$"
  {
    printf 'pid=%s\n' "$$"
    printf 'command=%s\n' "$(current_commandline)"
    printf 'started_at=%s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  } > "$owner_tmp"
  mv -f "$owner_tmp" "$RAGC_LOCK_OWNER_PATH"

  RAGC_LOCK_HELD=1
  trap_add 'release_global_lock'
  maybe_test_pause "after-lock"
}

with_global_lock() {
  local label="$1"
  shift

  acquire_global_lock
  log_info "Lock global adquirido: $label"
  "$@"
}
