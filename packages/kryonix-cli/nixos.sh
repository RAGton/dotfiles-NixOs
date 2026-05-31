write_default_host_skeleton() {
  local destination="$1"
  local skeleton_file
  skeleton_file="$(mktemp)"

  printf '%s\n' \
    '{ hostname, ... }:' \
    '{' \
    '  imports = [' \
    '    ./hardware-configuration.nix' \
    '  ];' \
    '  networking.hostName = hostname;' \
    '  system.stateVersion = "26.05";' \
    '}' > "$skeleton_file"

  run_privileged install -Dm0644 "$skeleton_file" "$destination"
  rm -f "$skeleton_file"
  bootstrap_host_created=1
}

ensure_local_hardware_config() {
  local local_hw_path="$1"
  local generated_hw
  local temp_hw

  if [[ -e "$local_hw_path" ]]; then
    return 0
  fi

  if ! command -v nixos-generate-config >/dev/null 2>&1; then
    printf '%s\n' "kryonix: não encontrei nixos-generate-config para gerar $local_hw_path" >&2
    return 1
  fi

  generated_hw="$(run_privileged nixos-generate-config --show-hardware-config)"
  temp_hw="$(mktemp)"
  printf '%s\n' "$generated_hw" > "$temp_hw"
  run_privileged install -Dm0644 "$temp_hw" "$local_hw_path"
  rm -f "$temp_hw"
  bootstrap_local_created=1
}

ensure_bootstrap_host_layout() {
  local repo_root="$1"
  local host_name="$2"
  local repo_host_dir="$repo_root/hosts/$host_name"
  local repo_host_default="$repo_host_dir/default.nix"
  local repo_hw="$repo_host_dir/hardware-configuration.nix"
  local local_host_dir="$repo_root/local/$host_name"
  local local_hw="$local_host_dir/hardware-configuration.nix"
  local existing_target

  if [[ -e "$repo_host_dir" && ! -d "$repo_host_dir" ]]; then
    printf '%s\n' "kryonix: $repo_host_dir existe, mas não é um diretório" >&2
    return 1
  fi

  if [[ ! -d "$repo_host_dir" ]]; then
    run_privileged install -d -m 0755 "$repo_host_dir"
    bootstrap_host_created=1
  fi

  if [[ -L "$repo_hw" ]]; then
    existing_target="$(readlink "$repo_hw")"
    if [[ "$existing_target" != "$local_hw" ]]; then
      printf '%s\n' "kryonix: conflito em $repo_hw: symlink aponta para $existing_target, esperado $local_hw" >&2
      return 1
    fi
  elif [[ -e "$repo_hw" ]]; then
    if [[ ! -d "$local_host_dir" ]]; then
      run_privileged install -d -m 0755 "$local_host_dir"
      bootstrap_local_created=1
    fi

    ensure_local_hardware_config "$local_hw" || return 1
    bootstrap_conflict_detected=1
  else
    if [[ ! -d "$local_host_dir" ]]; then
      run_privileged install -d -m 0755 "$local_host_dir"
      bootstrap_local_created=1
    fi

    ensure_local_hardware_config "$local_hw" || return 1
    run_privileged ln -s "$local_hw" "$repo_hw"
    bootstrap_symlink_created=1
  fi

  if [[ ! -e "$repo_host_default" ]]; then
    write_default_host_skeleton "$repo_host_default"
  fi
}

bootstrap_kryonix_checkout() {
  local host_name="$1"
  local repo_root="/etc/kryonix"
  local repo_source

  repo_source="$(resolve_bootstrap_repo_source)"

  if [[ -e "$repo_root/flake.nix" ]]; then
    return 0
  fi

  if [[ -e "$repo_root" && ! -e "$repo_root/flake.nix" ]]; then
    printf '%s\n' "kryonix: $repo_root existe, mas não contém flake.nix; não posso bootstrapar sem limpeza manual." >&2
    return 1
  fi

  if [[ -z "$repo_source" ]]; then
    printf '%s\n' 'kryonix: não existe repo configurado para bootstrap.' >&2
    return 1
  fi

  if ! run_privileged git clone --origin origin "$repo_source" "$repo_root"; then
    printf '%s\n' "kryonix: falha ao clonar $repo_source para $repo_root" >&2
    return 1
  fi

  bootstrap_performed=1
  bootstrap_repo_created=1
  bootstrap_repo_source="$repo_source"
  bootstrap_repo_root="$repo_root"

  ensure_bootstrap_host_layout "$repo_root" "$host_name" || return 1
  return 0
}

is_path_like_flake_ref() {
  local candidate="$1"

  case "$candidate" in
    path:*|/*|./*|../*|.|..)
      return 0
      ;;
  esac

  [[ -d "$candidate" ]]
}

use_local_flake() {
  local mode="$1"
  local root="$2"

  if [[ "$root" == path:* ]]; then
    root="${root#path:}"
  fi

  if [[ -z "$root" || ! -d "$root" ]]; then
    printf '%s\n' "kryonix: flake local inválida '$root'; esperado diretório com flake.nix." >&2
    return 1
  fi

  if [[ ! -e "$root/flake.nix" ]]; then
    printf '%s\n' "kryonix: flake local inválida '$root'; esperado arquivo flake.nix." >&2
    return 1
  fi

  flake_mode="$mode"
  flake_root="$root"
  flake_workdir="$root"
  flake_ref="."
}

use_flake_input() {
  local mode="$1"
  local candidate="$2"

  if is_path_like_flake_ref "$candidate"; then
    use_local_flake "$mode" "$candidate"
    return $?
  fi

  flake_mode="$mode"
  flake_root=""
  flake_workdir=""
  flake_ref="$candidate"
}

is_kryonix_test_target() {
  case "${1:-}" in
    all|code|client|server|runtime|brain|mcp|graph)
      return 0
      ;;
  esac

  return 1
}

run_kryonix_test_target() {
  local target="${1:-all}"
  local repo_root

  case "$target" in
    all)
      run_brain_cli test all
      repo_root="$(kryonix_repo_root)" || return 1
      run_command nix flake check "path:$repo_root" --keep-going
      ;;
    code)
      run_brain_cli test code
      repo_root="$(kryonix_repo_root)" || return 1
      run_command nix flake check "path:$repo_root" --keep-going
      ;;
    client)
      run_brain_cli test client
      ;;
    server)
      run_brain_cli test server
      ;;
    runtime)
      run_brain_cli test runtime
      ;;
    brain)
      run_brain_cli test brain
      ;;
    mcp)
      kryonix_mcp_check
      repo_root="$(kryonix_repo_root)" || return 1
      (
        cd "$repo_root"
        KRYONIX_BIN="$0" bash scripts/check-mcp.sh
      )
      ;;
    graph)
      run_brain_cli test graph
      ;;
    *)
      printf 'Uso: kryonix test <all|code|client|server|runtime|brain|mcp|graph>\n' >&2
      return 2
      ;;
  esac
}

resolve_flake() {
  local explicit="${1:-}"
  local local_root

  flake_mode=""
  flake_root=""
  flake_workdir=""
  flake_ref=""
  bootstrap_performed=0
  bootstrap_repo_created=0
  bootstrap_local_created=0
  bootstrap_host_created=0
  bootstrap_symlink_created=0
  bootstrap_conflict_detected=0
  bootstrap_repo_source=""
  bootstrap_repo_root=""

  if [[ -n "$explicit" ]]; then
    use_flake_input "explicit" "$explicit"
  elif [[ -n "${KRYONIX_FLAKE:-}" ]]; then
    use_flake_input "env" "$KRYONIX_FLAKE"
  elif local_root="$(find_local_flake_root)"; then
    # Se o root local é o upstream kryonix (motor) e o downstream existe,
    # os nixosConfigurations vivem no downstream — redireciona automaticamente.
    if is_kryonix_checkout "$local_root" && [[ -e /etc/kryonixos/flake.nix ]]; then
      use_local_flake "etc-kryonixos" "/etc/kryonixos"
    else
      use_local_flake "dev-repo" "$local_root"
    fi
  elif [[ -e /etc/kryonixos/flake.nix ]]; then
    use_local_flake "etc-kryonixos" "/etc/kryonixos"
  elif [[ -e /etc/kryonix/flake.nix ]]; then
    use_local_flake "etc-kryonix" "/etc/kryonix"
  else
    printf '%s\n' 'kryonix: não foi possível resolver uma flake.' >&2
    printf '%s\n' 'Use um destes caminhos:' >&2
    printf '%s\n' '- kryonix <comando> --flake /caminho/para/o/repo' >&2
    printf '%s\n' '- exporte KRYONIX_FLAKE com uma flake válida' >&2
    printf '%s\n' '- execute o comando dentro do checkout Git do projeto' >&2
    printf '%s\n' '- garanta que /etc/kryonixos/flake.nix exista (downstream)' >&2
    return 1
  fi
}

flake_lock_hash() {
  local lock_path="$1"

  if [[ ! -f "$lock_path" ]]; then
    printf '%s\n' "missing"
    return 0
  fi

  sha256sum "$lock_path" | sed 's/[[:space:]].*//'
}

update_flake_lock() {
  local include_extra="${1:-0}"
  local before_hash=""
  local after_hash=""
  local update_args=()

  update_args+=("${verbose_args[@]}")
  if (( include_extra )); then
    update_args+=("${extra_args[@]}")
  fi

  if [[ -n "$flake_workdir" ]]; then
    before_hash="$(flake_lock_hash "$flake_workdir/flake.lock")"
    run_flake_command nix flake update "${update_args[@]}"
    after_hash="$(flake_lock_hash "$flake_workdir/flake.lock")"

    if [[ "$before_hash" == "$after_hash" ]]; then
      blue_line 'OK: flake.lock já estava atualizado.'
    else
      blue_line 'OK: flake.lock atualizado.'
    fi
    return 0
  fi

  run_command nix flake update --flake "$flake_ref" "${update_args[@]}"
}

update_flake_if_requested() {
  if (( update )); then
    update_flake_lock 0
  elif (( verbose > 0 )); then
    blue_line '  update          : não solicitado; usando flake.lock atual'
  fi
}

print_flake_resolution() {
  if (( verbose > 0 )); then
    blue_line 'Kryonix CLI'
    blue_line "  host atual      : $(current_hostname)"
    blue_line "  modo detectado   : $flake_mode"
    blue_line "  flake resolvida  : $flake_ref"
    if [[ -n "$flake_root" ]]; then
      blue_line "  flake raiz       : $flake_root"
    fi
    if [[ -n "$flake_workdir" ]]; then
      blue_line "  diretório exec   : $flake_workdir"
    fi
    blue_line "  flake host       : $flake_host"
    blue_line "  update          : $(if (( update )); then printf 'sim'; else printf 'não'; fi)"
    if (( bootstrap_performed || bootstrap_repo_created || bootstrap_host_created || bootstrap_local_created || bootstrap_symlink_created || bootstrap_conflict_detected )); then
      blue_line '  bootstrap        : sim'
      if [[ -n "$bootstrap_repo_source" ]]; then
        blue_line "  repo origem      : $bootstrap_repo_source"
      fi
      if [[ -n "$bootstrap_repo_root" ]]; then
        blue_line "  repo raiz        : $bootstrap_repo_root"
      fi
      blue_line "  repo clonado     : $(if (( bootstrap_repo_created )); then printf 'sim'; else printf 'não'; fi)"
      blue_line "  host local       : $(if (( bootstrap_host_created )); then printf 'sim'; else printf 'não'; fi)"
      blue_line "  local file       : $(if (( bootstrap_local_created )); then printf 'sim'; else printf 'não'; fi)"
      blue_line "  symlink          : $(if (( bootstrap_symlink_created )); then printf 'sim'; else printf 'não'; fi)"
      blue_line "  bootstrap ok     : $(if (( bootstrap_performed )); then printf 'sim'; else printf 'não'; fi)"
      if (( bootstrap_conflict_detected )); then
        blue_line '  conflito         : arquivo versionado preservado'
      fi
    fi
  fi
}

kryonix_doctor_full() {
  local repo_path
  repo_path="$(kryonix_git_repo_path)"
  local has_error=0

  blue_line "======================================"
  blue_line "    KRYONIX DOCTOR FULL"
  blue_line "======================================"

  blue_line ""
  blue_line "--- [1] doctor docs ---"
  if [[ -x "$repo_path/scripts/doc-audit.sh" ]]; then
    if ! "$repo_path/scripts/doc-audit.sh"; then
      has_error=1
    fi
  else
    blue_line "ERRO: scripts/doc-audit.sh não encontrado."
    has_error=1
  fi

  blue_line ""
  blue_line "--- [2] doctor system ---"
  blue_line "  host atual   : $(current_hostname)"
  blue_line "  modo detectado: $flake_mode"
  blue_line "  flake resolvida: $flake_ref"

  if command -v systemctl >/dev/null 2>&1; then
    blue_line "  libvirtd     : $(systemctl is-enabled libvirtd 2>/dev/null || printf 'unknown')"
    blue_line "  tailscaled   : $(systemctl is-active tailscaled 2>/dev/null || printf 'inactive')"
  fi

  if ss -ltnp 2>/dev/null | grep -q 11434; then
      blue_line "  ollama       : ativo"
  else
      blue_line "  ollama       : inativo"
  fi

  blue_line ""
  blue_line "--- [3] doctor architecture ---"
  for doc in ARCHITECTURE.md ROADMAP.md USAGE.md TESTING.md; do
    if [[ -f "$repo_path/docs/$doc" ]]; then
      blue_line "  ✓ docs/$doc encontrado."
    else
      blue_line "  ERRO: docs/$doc ausente."
      has_error=1
    fi
  done

  blue_line ""
  blue_line "--- [4] doctor brain ---"
  brain_url="$(brain_api_url)"
  if [[ -n "$brain_url" ]]; then
    blue_line "  brain url    : $brain_url"
    if curl -s --connect-timeout 2 "$brain_url/health" >/dev/null; then
      blue_line '  brain health : OK'
    else
      blue_line '  brain health : FAIL'
    fi
  elif [[ "$(kryonix_brain_role)" == "client" ]]; then
    blue_line '  brain remoto : WARN: KRYONIX_BRAIN_API ausente'
  else
    blue_line '  brain remoto : inativo (server)'
  fi

  blue_line ""
  blue_line "--- [5] doctor summary ---"
  if [[ "$has_error" -eq 1 ]]; then
    blue_line "ERRO CRÍTICO: kryonix doctor full encontrou falhas."
    return 1
  else
    blue_line "✓ kryonix doctor full concluído sem erros críticos."
    return 0
  fi
}

accepts_positional_host() {
  case "$subcommand" in
    switch|boot|test|home|rebuild|diff|doctor)
      return 0
      ;;
  esac

  return 1
}
