# Kryonix CLI — Central de Operações do Sistema
# Copyright (c) 2026 Gabriel Aguiar Rocha. All rights reserved.
# Licença: Source Available / Proprietário

print_banner() {
  if [[ "${json_mode:-0}" -eq 1 ]]; then return 0; fi

  if [[ -n "$blue" ]]; then
    printf '%b' "$blue"
    printf '   _  __                         _      \n'
    printf '  | |/ /                        (_)     \n'
    printf '  |   /  _ __  _   _   ___   _ __  _ __  __\n'
    printf '  |  <  | '\''__| | | | | / _ \ | '\''_ \| || \/ /\n'
    printf '  | . \ | |    | |_| || (_) || | | | | >  < \n'
    printf '  |_|\_\|_|     \__, | \___/ |_| |_|_|/_/\_\\\n'
    printf '                 __/ |                      \n'
    printf '                |___/                       \n'
    printf '%b' "$reset"
  else
    printf 'Kryonix CLI\n'
  fi
  printf '──────────────────────────────────────────────────────────\n'
}

print_usage() {
  print_banner

  local group cmd desc
  local -A group_labels=(
    [system]="🖥️  Comandos de Sistema"
    [home]="🏠 Home & Auditoria"
    [brain]="🧠 Kryonix Brain"
    [graph]="🕸️  Graph"
    [mcp]="🔌 MCP"
    [vault]="📖 Vault"
    [utils]="⚡ Utilidades"
  )

  local current_group=""
  local line group cmd sub desc
  for line in "${KRYONIX_REGISTRY[@]}"; do
    IFS='|' read -r group cmd sub desc _ <<< "$line"
    if [[ -n "$sub" ]]; then continue; fi # Pula subcomandos no help global

    if [[ "$group" != "$current_group" ]]; then
      if [[ -n "$current_group" ]]; then printf '\n'; fi
      printf '  %b\033[1m%s\033[0m\n' "$blue" "${group_labels[$group]:-$group}"
      current_group="$group"
    fi
    printf '    %-10s %s\n' "$cmd" "$desc"
  done

  printf '\n  ⚙️  \033[1mOpções Globais\033[0m\n'
  printf '    --host <h>   Define alvo (glacier, inspiron)\n'
  printf '    --flake <p>  Define caminho da flake\n'
  printf '    --update     Força atualização de inputs\n'
  printf '    --dry        Simulação segura\n'
  printf '    --json       Saída em formato JSON\n'
  printf '\n'
  printf '  💡 \033[1mExemplos\033[0m\n'
  printf '    kryonix switch all --update\n'
  printf '    kryonix brain search "pipeline"\n'
  printf '──────────────────────────────────────────────────────────\n'
}

print_subcommand_help() {
  local parent="$1"
  print_banner

  local desc
  desc="$(kryonix_get_description "$parent")"
  printf '  🚀 \033[1m%s\033[0m — %s\n' "${parent^^}" "$desc"
  printf '  Uso: kryonix %s [subcomando] [opções]\n\n' "$parent"

  local sub flags examples risk host runtime sudo cat status
  local line c s d f ex r _ _ sd _ st
  local found=0
  for line in "${KRYONIX_REGISTRY[@]}"; do
    IFS='|' read -r _ c s d f ex r _ _ sd _ st <<< "$line"
    if [[ "$c" == "$parent" && -n "$s" ]]; then
      local risk_color="\e[32m" # low: green
      case "$r" in
        medium) risk_color="\e[33m" ;; # yellow
        high) risk_color="\e[31m" ;; # red
        critical) risk_color="\e[1;97;45m" ;; # white on magenta bold
      esac

      printf '    %-15s %s' "$s" "$d"
      if [[ -n "$r" ]]; then
        printf " (${risk_color}%s\033[0m)" "$r"
      fi
      printf "\n"

      if [[ -n "$f" ]]; then
        printf '      \e[2mFlags: %s\e[0m\n' "$f"
      fi
      if [[ -n "$ex" ]]; then
        printf '      \e[2mEx: %s\e[0m\n' "$ex"
      fi
      if [[ "$sd" == "true" ]]; then
        printf '      \033[31m[!] Requer sudo\033[0m\n'
      fi
      found=1
    fi
  done

  if [[ $found -eq 0 ]]; then
    printf '  Esta seção não possui subcomandos ou o help específico ainda não foi detalhado no registry.\n'
  fi

  printf '\n──────────────────────────────────────────────────────────\n'
}

reject_unexpected_positional_args() {
  local command_label="$1"
  local usage_line="$2"
  local arg

  for arg in "${extra_args[@]}"; do
    if [[ "$arg" != -* ]]; then
      printf 'kryonix: argumento posicional inesperado para "%s": %s\n' "$command_label" "$arg" >&2
      printf 'Uso: %s\n' "$usage_line" >&2
      printf 'Para definir a flake, use --flake <flake> ou KRYONIX_FLAKE=<flake>.\n' >&2
      exit 2
    fi
  done
}

run_post_switch_gc() {
  if [[ "${KRYONIX_POST_SWITCH_GC:-1}" == "0" ]]; then
    printf 'Limpeza automática pós-switch desativada via KRYONIX_POST_SWITCH_GC=0.\n'
    return 0
  fi

  printf 'Executando limpeza automática pós-switch (removendo gerações > 2 dias)...\n'

  # Limpa arquivos de backup antigos do Home Manager no diretório home do usuário alvo
  if [[ -n "${user_arg:-}" ]]; then
    local target_home
    target_home="$(getent passwd "$user_arg" | cut -d: -f6)"
    if [[ -n "$target_home" && -d "$target_home" ]]; then
      find "$target_home" -maxdepth 5 -type f \( -name "*.hm-old" -o -name "*.hm-bak" \) -mtime +2 -delete 2>/dev/null || true
    fi
  fi

  if command -v nh >/dev/null 2>&1; then
    if ! run_command nh clean all --keep-since 2d; then
      printf '\033[33m[warn]\033[0m Falha na limpeza automática pós-switch via nh.\n' >&2
    fi
    return 0
  fi

  if ! run_command nix-collect-garbage --delete-older-than 2d; then
    printf '\033[33m[warn]\033[0m Falha na limpeza automática pós-switch via nix-collect-garbage.\n' >&2
  fi
}


# --- Inicialização ---
init_colors

# Garante que o sudo com setuid está antes do sudo sem setuid do nix store.
# /run/wrappers/bin/sudo tem -r-s--x--x; /run/current-system/sw/bin/sudo não tem setuid.
if [[ -d /run/wrappers/bin ]]; then
  PATH="/run/wrappers/bin${PATH:+:$PATH}"
  export PATH
fi

# --- Parsing de Argumentos ---
subcommand="${1:-}"
if [[ -n "$subcommand" ]]; then
  shift
fi

host_arg=""
# Auto-detects current user. Handles sudo escalation via SUDO_USER.
user_arg="${SUDO_USER:-${USER:-$(id -un 2>/dev/null || printf 'rocha')}}"
flake_arg=""
verbose=0
json_mode=0
dry=0
update=0
extra_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --update|-u)
      update=1
      ;;
    --no-update)
      update=0
      ;;
    --verbose|-v)
      verbose=$((verbose + 1))
      ;;
    --json)
      json_mode=1
      export KRYONIX_JSON_MODE=1
      extra_args+=("$1")
      ;;
    --dry|-n)
      dry=1
      ;;
    --host|-H)
      if [[ $# -lt 2 ]]; then
        printf '%s\n' 'kryonix: --host requer um valor.' >&2
        exit 2
      fi
      host_arg="$2"
      shift
      ;;
    --user)
      if [[ $# -lt 2 ]]; then
        printf '%s\n' 'kryonix: --user requer um valor.' >&2
        exit 2
      fi
      user_arg="$2"
      shift
      ;;
    --flake)
      if [[ $# -lt 2 ]]; then
        printf '%s\n' 'kryonix: --flake requer um valor.' >&2
        exit 2
      fi
      flake_arg="$2"
      shift
      ;;
    --help|-h)
      if [[ "$subcommand" == "home" || "$subcommand" == "graph" || "$subcommand" == "brain" || "$subcommand" == "mcp" || \
            "$subcommand" == "vault" || "$subcommand" == "remote" || "$subcommand" == "switch" || "$subcommand" == "boot" || \
            "$subcommand" == "ollama" || "$subcommand" == "ai" || "$subcommand" == "rgb" || "$subcommand" == "all" || \
            "$subcommand" == "install" || "$subcommand" == "hardware" || "$subcommand" == "disk" ]]; then
        extra_args+=("$1")
      else
        print_usage
        exit 0
      fi
      ;;
    --)
      shift
      extra_args+=("$@")
      break
      ;;
    *)
      if [[ "$1" == ".#"* ]] || [[ "$1" == ". #"* ]]; then
        printf 'ERRO: Sintaxe ".#host" ou ". #host" não permitida.\n' >&2
        printf 'Use: kryonix %s --host <host>\n' "$subcommand" >&2
        exit 1
      fi

      # Verificação de target de teste
      is_test_target=0
      case "$1" in
        all|client|server|code|mcp) is_test_target=1 ;;
      esac

      # Verificação de host posicional
      is_positional_host=0
      case "$subcommand" in
        switch|boot|test|rebuild|diff|repl|doctor) is_positional_host=1 ;;
      esac

      if [[ "$subcommand" == "test" ]] && [[ $is_test_target -eq 1 ]]; then
        extra_args+=("$1")
      elif [[ $is_positional_host -eq 1 ]] && [[ -z "$host_arg" && "$1" != -* ]]; then
        if [[ "$subcommand" == "home" ]] && [[ "$1" == "scan" || "$1" == "report" || "$1" == "duplicates" || "$1" == "plan" || "$1" == "manifest" || "$1" == "apply" || "$1" == "rollback" || "$1" == "autopilot" || "$1" == "categories" || "$1" == "explain" || "$1" == "export-memory" || "$1" == "projects" || "$1" == "diagnose" || "$1" == "dashboard" || "$1" == "inbox" || "$1" == "review" || "$1" == "state" ]]; then
          extra_args+=("$1")
        elif [[ "$subcommand" == "switch" || "$subcommand" == "boot" || "$subcommand" == "test" || "$subcommand" == "rebuild" || "$subcommand" == "diff" ]] && is_path_like_flake_ref "$1"; then
          printf 'kryonix: argumento "%s" parece caminho/flake, não host.\n' "$1" >&2
          printf 'Uso: kryonix %s [<host>|all] [--flake <flake>]\n' "$subcommand" >&2
          printf 'Para definir a flake, use --flake <flake> ou KRYONIX_FLAKE=<flake>.\n' >&2
          exit 2
        else
          host_arg="$1"
        fi
      else
        extra_args+=("$1")
      fi
      ;;
  esac
  shift
done

if [[ "$subcommand" == "test" ]] && [[ "$EUID" -eq 0 ]]; then
   printf 'ERRO: "kryonix test" não deve ser executado com sudo.\n' >&2
   exit 1
fi

# Para subcomandos delegados, não interceptar --help aqui;
# delegar ao backend real para que ele mostre seu próprio help.
delegate_nested_help=false

if [[ "${#extra_args[@]}" -gt 0 ]]; then
  case "$subcommand" in
    home)
      case "${extra_args[0]}" in
        scan|report|duplicates|plan|manifest|apply|rollback|autopilot|categories|explain|export-memory|projects|diagnose|dashboard|inbox|review|state)
          delegate_nested_help=true
          ;;
      esac
      ;;
    brain)
      case "${extra_args[0]}" in
        health|doctor|stats|vault-scan|search|ask|storage-check|ollama-check|sync|watch|index|export|diagnostics|api|cag|api-key|preflight-secrets|rotate-api-key|deploy-safe|remote|autopilot)
          delegate_nested_help=true
          ;;
      esac
      ;;
  esac
fi

if [[ "$delegate_nested_help" != "true" ]]; then
  for arg in "${extra_args[@]}"; do
    if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
      print_subcommand_help "$subcommand"
      exit 0
    fi
  done
fi

flake_host="${host_arg:-$(map_runtime_host)}"
# Mapeamento do alias 'all'
if [[ "$flake_host" == "all" ]]; then
  flake_host="$(map_runtime_host)"
  apply_all=1
  if [[ "$subcommand" == "switch" || "$subcommand" == "boot" ]]; then
    reject_unexpected_positional_args "$subcommand all" "kryonix $subcommand all [--update] [--dry] [--flake <flake>]"
  fi
else
  apply_all=0
fi

if [[ "$subcommand" == "all" ]]; then
  reject_unexpected_positional_args "all" "kryonix all [--update] [--dry] [--flake <flake>]"
fi

case "$subcommand" in
  help|--help|-h|"")
    print_usage
    exit 0
    ;;

  commands)
    if [[ "$json_mode" -eq 1 ]]; then
      kryonix_get_registry_json
    elif [[ "${extra_args[0]:-}" == "--plain" ]]; then
      for cmd in $(kryonix_get_commands); do
        kryonix_get_subcommands "$cmd" | while read -r sub; do
          printf "%s %s\n" "$cmd" "$sub"
        done
      done
    elif [[ "${extra_args[0]:-}" == "--groups" ]]; then
      kryonix_get_groups
    elif [[ "${extra_args[0]:-}" == "--subcommands" ]]; then
      if [[ -n "${extra_args[1]:-}" ]]; then
        kryonix_get_subcommands "${extra_args[1]}"
      else
        printf "ERRO: --subcommands requer um grupo.\n" >&2
        exit 1
      fi
    elif [[ "${extra_args[0]:-}" == "--flags" ]]; then
      if [[ -n "${extra_args[1]:-}" ]]; then
        kryonix_get_flags "${extra_args[1]}" "${extra_args[2]:-}"
      else
        printf "ERRO: --flags requer um comando.\n" >&2
        exit 1
      fi
    else
      kryonix_get_commands
    fi
    exit 0
    ;;

  __complete)
    shell="${1:-bash}"
    case "$shell" in
      bash|zsh|fish)
        # Interface para ser chamada pelos scripts de completion se necessário
        # Mas os scripts de completion podem simplesmente chamar 'kryonix commands --plain' etc.
        ;;
    esac
    exit 0
    ;;

  clean|vm|git-status|pull|deploy|sync|brain|graph|mcp|vault|rgb|ollama|ai|remote|install|hardware|disk|env)
    needs_flake=0
    ;;

  test)
    if is_kryonix_test_target "${extra_args[0]:-}"; then
      needs_flake=0
    else
      needs_flake=1
    fi
    ;;

  home)
    if [[ "${#extra_args[@]}" -gt 0 ]] && [[ "${extra_args[0]}" == "scan" || "${extra_args[0]}" == "report" || "${extra_args[0]}" == "duplicates" || "${extra_args[0]}" == "plan" || "${extra_args[0]}" == "manifest" || "${extra_args[0]}" == "apply" || "${extra_args[0]}" == "rollback" || "${extra_args[0]}" == "autopilot" || "${extra_args[0]}" == "categories" || "${extra_args[0]}" == "explain" || "${extra_args[0]}" == "export-memory" || "${extra_args[0]}" == "projects" || "${extra_args[0]}" == "dashboard" || "${extra_args[0]}" == "inbox" || "${extra_args[0]}" == "review" || "${extra_args[0]}" == "diagnose" || "${extra_args[0]}" == "state" ]]; then
      needs_flake=0
    else
      needs_flake=1
    fi
    ;;

  *)
    needs_flake=1
    ;;
esac

if (( needs_flake )); then
  resolve_flake "$flake_arg"
else
  flake_mode="none"
  flake_root=""
  flake_workdir=""
  flake_ref=""
fi

# Inferência automática de host: valida $flake_host contra nixosConfigurations.
# Só para comandos que constroem/aplicam uma configuração NixOS de host.
if (( needs_flake )); then
  case "$subcommand" in
    switch|boot|rebuild|diff)
      infer_or_verify_host || exit 1
      ;;
  esac
fi

home_target="${user_arg}@${flake_host}"
verbose_args=()
dry_args=()

verbose_count="$verbose"
while (( verbose_count > 0 )); do
  verbose_args+=("-v")
  verbose_count=$((verbose_count - 1))
done

if (( needs_flake )); then
  print_flake_resolution
fi

if (( dry )); then
  dry_args+=("--dry")
fi

run_flake_command_smart_hm() {
  local tmp_log
  tmp_log="$(mktemp)"
  
  # Captura a saída para detectar o erro chato do home-manager, mas mantendo o log na tela
  if ! run_flake_command "$@" > >(tee -a "$tmp_log") 2> >(tee -a "$tmp_log" >&2); then
    local rc=$?
    if grep -q "would be clobbered by backing up" "$tmp_log"; then
      local backup_file
      backup_file="$(grep "would be clobbered by backing up" "$tmp_log" | sed -n "s/.*Existing file '\(.*\)' would be clobbered.*/\1/p" | head -n 1)"
      
      if [[ -n "$backup_file" && -f "$backup_file" ]]; then
        printf '\n\033[33m[kryonix switch inteligente]\033[0m Conflito de backup detectado: %s\n' "$backup_file" >&2
        printf '\033[33m[kryonix switch inteligente]\033[0m Removendo arquivo conflitante e tentando novamente...\n\n' >&2
        rm -f "$backup_file"
        rm -f "$tmp_log"
        # Retry
        run_flake_command "$@"
        return $?
      fi
    fi
    rm -f "$tmp_log"
    return "$rc"
  fi
  rm -f "$tmp_log"
  return 0
}

case "$subcommand" in
  switch|boot)
    update_flake_if_requested

    # OS Switch
    cmd=(nh os "$subcommand" "$flake_ref" -H "$flake_host")
    cmd+=("${verbose_args[@]}" "${dry_args[@]}")
    if [[ "${#extra_args[@]}" -gt 0 ]]; then
      cmd+=("--" "${extra_args[@]}")
    fi
    run_flake_command_smart_hm "${cmd[@]}"
    switch_rc=$?
    if (( switch_rc != 0 )); then
      exit "$switch_rc"
    fi

    # Se 'all' for usado, aplica Home Manager em seguida
    if (( apply_all )); then
      blue_line "─── Aplicando Home Manager (Kryonix All) ───"
      cmd=(nh home switch "$flake_ref" -c "$home_target" -b hm-old)
      cmd+=("${verbose_args[@]}" "${dry_args[@]}")
      run_flake_command_smart_hm "${cmd[@]}"
    fi

    if [[ "$subcommand" == "switch" ]]; then
      run_post_switch_gc
    fi
    ;;

  all)
    update_flake_if_requested
    flake_host="$(map_runtime_host)"

    # OS Switch
    cmd=(nh os switch "$flake_ref" -H "$flake_host")
    cmd+=("${verbose_args[@]}" "${dry_args[@]}")
    run_flake_command_smart_hm "${cmd[@]}"
    all_switch_rc=$?
    if (( all_switch_rc != 0 )); then
      exit "$all_switch_rc"
    fi

    # Home Switch — falha não-fatal: sistema funcional mesmo se HM falhar
    home_target="${user_arg}@${flake_host}"
    blue_line "─── Aplicando Home Manager (Kryonix All) ───"
    cmd=(nh home switch "$flake_ref" -c "$home_target" -b hm-old)
    cmd+=("${verbose_args[@]}" "${dry_args[@]}")
    if ! run_flake_command_smart_hm "${cmd[@]}"; then
      printf '\033[33m[warn]\033[0m NixOS OK, mas HM falhou — sistema funcional, home config desatualizada.\n' >&2
      printf '\033[33m[warn]\033[0m Execute: home-manager switch --flake %s#%s -b hm-old\n' "$flake_ref" "$home_target" >&2
    fi

    run_post_switch_gc

    # ── Post-switch: sincronização do grafo Neo4j ──
    # PENDÊNCIA (Kora removida): o sync pós-switch do grafo era feito por
    # `kora /brain sync`. Será reimplementado na camada Aura/Brain.
    # Ver docs/aura/KORA_RETIREMENT_STUDY.md (§4).
    ;;

  test)
    if is_kryonix_test_target "${extra_args[0]:-}"; then
      run_kryonix_test_target "${extra_args[0]}"
    else
      update_flake_if_requested
      cmd=(nh os test "$flake_ref" -H "$flake_host")
      cmd+=("${verbose_args[@]}" "${dry_args[@]}")
      if [[ "${#extra_args[@]}" -gt 0 ]]; then
        cmd+=("--" "${extra_args[@]}")
      fi
      run_flake_command "${cmd[@]}"
    fi
    ;;

  home)
    # Delegação para o binário Rust kryonix-home (Home Brain)
    if [[ "${#extra_args[@]}" -gt 0 ]]; then
      case "${extra_args[0]}" in
        scan|report|duplicates|plan|manifest|apply|rollback|autopilot|categories|explain|export-memory|projects|diagnose|dashboard|inbox|review|state|help|--help|-h)
          kryonix_home "${extra_args[@]}"
          exit $?
          ;;
      esac
    fi

    # Comportamento legado: Home Manager switch via nh
    update_flake_if_requested
    cmd=(nh home switch "$flake_ref" -c "$home_target")
    cmd+=("${verbose_args[@]}" "${dry_args[@]}")
    if [[ "${#extra_args[@]}" -gt 0 ]]; then
      cmd+=("--" "${extra_args[@]}")
    fi
    run_flake_command "${cmd[@]}"
    ;;

  rebuild)
    update_flake_if_requested
    cmd=(nix build "${flake_ref}#nixosConfigurations.${flake_host}.config.system.build.toplevel")
    cmd+=("${verbose_args[@]}" "${extra_args[@]}")
    run_flake_command "${cmd[@]}"
    ;;

  update)
    # Em PROD, `kryonix update` jamais roda `nix flake update`. Faz apenas
    # `git pull --ff-only` + check + diff. Detalhes em
    # docs/operations/KRYONIX_UPDATE_POLICY.md.
    update_env="$(kryonix_detect_env "${flake_workdir:-$PWD}")"
    if kryonix_env_is_prod "$update_env"; then
      blue_line "kryonix update (PROD): git pull --ff-only + check + diff"
      kryonix_pull_repo || exit $?
      cmd=(nix flake check "$flake_ref" --keep-going "${verbose_args[@]}")
      run_flake_command "${cmd[@]}" || exit $?
      target_path="$(capture_flake_command nix build --no-link --print-out-paths "${flake_ref}#nixosConfigurations.${flake_host}.config.system.build.toplevel")"
      run_command nvd diff /run/current-system "$target_path"
    else
      update_flake_lock 1
    fi
    ;;

  clean)
    cmd=(nh clean all "${verbose_args[@]}" "${extra_args[@]}")
    run_command "${cmd[@]}"
    ;;

  diff)
    target_path="$(capture_flake_command nix build --no-link --print-out-paths "${flake_ref}#nixosConfigurations.${flake_host}.config.system.build.toplevel" "${extra_args[@]}")"
    run_command nvd diff /run/current-system "$target_path"
    ;;

  pull)
    kryonix_pull_repo
    ;;

  deploy)
    kryonix_deploy_repo
    ;;

  sync)
    kryonix_sync_repo
    ;;

  repl)
    cmd=(nix repl "$flake_ref" "${extra_args[@]}")
    run_flake_command "${cmd[@]}"
    ;;

  doctor)
    if [[ "${extra_args[0]:-}" == "full" ]]; then
      kryonix_doctor_full
      exit $?
    fi

    _ok=$'\033[32m✓\033[0m'
    _warn=$'\033[33m!\033[0m'
    _fail=$'\033[31m✗\033[0m'

    printf '\n\033[1;34m════════════════════════════════════════\033[0m\n'
    printf '\033[1;34m  KRYONIX DOCTOR\033[0m\n'
    printf '\033[1;34m════════════════════════════════════════\033[0m\n\n'

    # ── Sistema ────────────────────────────────────────────────────────────────
    printf '\033[1m[Sistema]\033[0m\n'
    printf '  hostname         : %s\n' "$(current_hostname)"
    _nixver="$(nixos-version 2>/dev/null || cat /etc/os-release 2>/dev/null | grep VERSION_ID | cut -d= -f2 || echo '?')"
    printf '  nixos-version    : %s\n' "$_nixver"
    _gen="$(readlink /run/current-system 2>/dev/null | grep -o 'nixos-system[^/]*' || echo '?')"
    printf '  geração nixos    : %s\n' "$_gen"

    # ── Flake ──────────────────────────────────────────────────────────────────
    printf '\n\033[1m[Flake]\033[0m\n'
    printf '  modo             : %s\n' "${flake_mode:-?}"
    printf '  path             : %s\n' "${flake_workdir:-${flake_root:-${flake_ref:-?}}}"
    printf '  host             : %s\n' "${flake_host:-?}"
    printf '  usuário          : %s\n' "${user_arg:-?}"
    printf '  home target      : %s\n' "${home_target:-?}"

    # Hosts disponíveis no flake (rápido, sem build)
    _hosts="$(list_nixos_hosts 2>/dev/null | tr '\n' ' ' || echo '?')"
    printf '  hosts no flake   : %s\n' "${_hosts:-?}"

    # Verifica se flake_host existe nos hosts
    if echo "$_hosts" | grep -qw "${flake_host:-}"; then
      printf '  host no flake    : %s %s\n' "$_ok" "${flake_host}"
    else
      printf '  host no flake    : %s %s NÃO encontrado em [%s]\n' "$_fail" "${flake_host:-?}" "$_hosts"
    fi

    # ── Home Manager ───────────────────────────────────────────────────────────
    printf '\n\033[1m[Home Manager]\033[0m\n'
    _hm_gen="$(readlink "${HOME}/.local/state/nix/profiles/home-manager" 2>/dev/null \
      | grep -o 'home-manager-[0-9]*-link' || echo '?')"
    printf '  geração          : %s\n' "$_hm_gen"
    _hm_conf="${HOME}/.config/hypr/hyprland.conf"
    if [[ -L "$_hm_conf" ]]; then
      printf '  hyprland.conf    : %s symlink OK\n' "$_ok"
    elif [[ -f "$_hm_conf" ]]; then
      printf '  hyprland.conf    : %s arquivo regular (stub?)\n' "$_warn"
    else
      printf '  hyprland.conf    : %s ausente\n' "$_fail"
    fi

    # ── Git ────────────────────────────────────────────────────────────────────
    printf '\n\033[1m[Git]\033[0m\n'
    _kryonix_root="$(git -C /etc/kryonix rev-parse --show-toplevel 2>/dev/null || echo '')"
    if [[ -n "$_kryonix_root" ]]; then
      _kryonix_st="$(git -C "$_kryonix_root" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
      _kryonix_rev="$(git -C "$_kryonix_root" rev-parse --short HEAD 2>/dev/null || echo '?')"
      if [[ "$_kryonix_st" -eq 0 ]]; then
        printf '  kryonix          : %s clean (%s)\n' "$_ok" "$_kryonix_rev"
      else
        printf '  kryonix          : %s %s alterações não commitadas (%s)\n' "$_warn" "$_kryonix_st" "$_kryonix_rev"
      fi
    else
      printf '  kryonix          : %s /etc/kryonix não encontrado\n' "$_fail"
    fi

    _kryonixos_root="$(git -C /etc/kryonixos rev-parse --show-toplevel 2>/dev/null || echo '')"
    if [[ -n "$_kryonixos_root" ]]; then
      _kryonixos_st="$(git -C "$_kryonixos_root" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
      _kryonixos_rev="$(git -C "$_kryonixos_root" rev-parse --short HEAD 2>/dev/null || echo '?')"
      if [[ "$_kryonixos_st" -eq 0 ]]; then
        printf '  kryonixos        : %s clean (%s)\n' "$_ok" "$_kryonixos_rev"
      else
        printf '  kryonixos        : %s %s alterações não commitadas (%s)\n' "$_warn" "$_kryonixos_st" "$_kryonixos_rev"
      fi
    else
      printf '  kryonixos        : %s /etc/kryonixos não encontrado\n' "$_fail"
    fi

    # ── Serviços ───────────────────────────────────────────────────────────────
    printf '\n\033[1m[Serviços]\033[0m\n'
    if command -v systemctl >/dev/null 2>&1; then
      _sddm="$(systemctl is-active display-manager 2>/dev/null; true)"
      _tail="$(systemctl is-active tailscaled 2>/dev/null; true)"
      _libvirt="$(systemctl is-enabled libvirtd 2>/dev/null; true)"
      printf '  display-manager  : %s\n' "$_sddm"
      printf '  tailscaled       : %s\n' "$_tail"
      printf '  libvirtd         : %s\n' "$_libvirt"
    fi
    if ss -ltnp 2>/dev/null | grep -q 11434; then
      printf '  ollama           : %s ativo (porta 11434)\n' "$_ok"
    else
      printf '  ollama           : inativo\n'
    fi

    # ── Brain ──────────────────────────────────────────────────────────────────
    _brain_url="$(brain_api_url 2>/dev/null || true)"
    if [[ -n "$_brain_url" ]]; then
      printf '\n\033[1m[Brain]\033[0m\n'
      printf '  url              : %s\n' "$_brain_url"
      if curl -s --connect-timeout 2 "$_brain_url/health" >/dev/null 2>&1; then
        printf '  health           : %s OK\n' "$_ok"
      else
        printf '  health           : %s FAIL\n' "$_fail"
      fi
    fi

    printf '\n\033[1;34m════════════════════════════════════════\033[0m\n'
    printf '  Use \033[1mkryonix doctor full\033[0m para diagnóstico completo\n\n'
    ;;

  git-status)
    print_kryonix_git_status
    ;;

  env)
    env_sub="${extra_args[0]:-status}"
    case "$env_sub" in
      status|"")
        print_kryonix_env_status
        ;;
      *)
        printf 'kryonix env: subcomando desconhecido "%s" (use: status)\n' "$env_sub" >&2
        exit 2
        ;;
    esac
    ;;


  vm)
    run_command virsh list --all
    ;;

  iso)
    iso_mode="online"
    filtered_args=()
    
    # Extrair --mode dos extra_args
    for (( i=0; i < ${#extra_args[@]}; i++ )); do
      if [[ "${extra_args[i]}" == "--mode" ]]; then
        iso_mode="${extra_args[i+1]}"
        ((i++))
      else
        filtered_args+=("${extra_args[i]}")
      fi
    done

    offline_val="false"
    if [[ "$iso_mode" == "offline" ]]; then
      offline_val="true"
    fi

    # Usamos o wrapper iso.nix para suportar o argumento dinâmico --arg
    # Note: assume que o CLI está rodando no root do repositório ou que resolvemos o path.
    cmd=(nix build --arg offlineMode "$offline_val" -f "$flake_root/iso.nix" "${verbose_args[@]}" "${filtered_args[@]}")
    
    blue_line "Construindo ISO em modo: ${iso_mode^^}..."
    run_command "${cmd[@]}" || exit $?

    blue_line "✅ ISO gerada em modo ${iso_mode^^}."
    # Tenta localizar o arquivo .iso e mostrar o tamanho
    iso_file=$(find result/ -name "*.iso" 2>/dev/null | head -n 1)
    if [[ -n "$iso_file" ]]; then
       size=$(du -sh "$iso_file" | awk '{print $1}')
       blue_line "Tamanho final: $size"
    else
       blue_line "Tamanho final: (não foi possível localizar o arquivo .iso em result/)"
    fi
    ;;

  fmt)
    cmd=(nix fmt "$flake_ref" "${verbose_args[@]}" "${extra_args[@]}")
    run_flake_command "${cmd[@]}"
    ;;

  check)
    cmd=(nix flake check "$flake_ref" --keep-going "${verbose_args[@]}" "${extra_args[@]}")
    run_flake_command "${cmd[@]}"
    ;;

  rgb)
    kryonix_rgb "${extra_args[@]}"
    ;;

  brain)
    if [[ "${#extra_args[@]}" -eq 0 ]]; then
      brain_sub="help"
    else
      brain_sub="${extra_args[0]}"
      extra_args=("${extra_args[@]:1}")
    fi

    case "$brain_sub" in
      health)
        kryonix_brain_health "${extra_args[@]}"
        ;;
      doctor)
        kryonix_brain_doctor "${extra_args[@]}"
        ;;
      stats)
        kryonix_brain_stats "${extra_args[@]}"
        ;;
      normalize)
        kryonix_brain_normalize "${extra_args[@]}"
        ;;
      vault-scan)
        kryonix_brain_vault_scan "${extra_args[@]}"
        ;;
      search|ask)
        if [[ "${#extra_args[@]}" -eq 0 ]]; then
          printf 'Uso: kryonix brain %s "pergunta" [--explain] [--remote|--local]\n' "$brain_sub" >&2
          exit 2
        fi
        kryonix_brain_search "$brain_sub" "${extra_args[@]}"
        ;;
      storage-check|ollama-check)
        run_brain_cli "$brain_sub" "${extra_args[@]}"
        ;;
      sync|watch|diagnostics|index|export|autopilot)
        run_brain_cli "$brain_sub" "${extra_args[@]}"
        ;;
      api)
        run_brain_module kryonix_brain_lightrag.api "${extra_args[@]}"
        ;;
      cag)
        kryonix_brain_cag "${extra_args[@]}"
        ;;
      api-key)
        kryonix_brain_api_key "${extra_args[@]}"
        ;;
      preflight-secrets)
        kryonix_brain_preflight_secrets "${extra_args[@]}"
        ;;
      rotate-api-key)
        kryonix_brain_rotate_api_key "${extra_args[@]}"
        ;;
      deploy-safe)
        kryonix_brain_deploy_safe "${extra_args[@]}"
        ;;
      remote)
        kryonix_brain_remote "${extra_args[@]}"
        ;;
      vram-audit)
        kryonix_brain_vram_audit "${extra_args[@]}"
        ;;
      vram-check)
        kryonix_brain_vram_check "${extra_args[@]}"
        ;;
      vram-clear)
        kryonix_brain_vram_clear "${extra_args[@]}"
        ;;
      vram-profile)
        kryonix_brain_vram_profile "${extra_args[@]}"
        ;;
      llama-cpp)
        kryonix_brain_llama_cpp "${extra_args[@]}"
        ;;
      provider)
        kryonix_brain_provider "${extra_args[@]}"
        ;;
      start)
        kryonix_brain_stack_start "${extra_args[@]}"
        ;;
      stop)
        kryonix_brain_stack_stop "${extra_args[@]}"
        ;;
      restart)
        kryonix_brain_stack_restart "${extra_args[@]}"
        ;;
      status)
        kryonix_brain_stack_status "${extra_args[@]}"
        ;;
       *)
         echo "Uso: kryonix brain <start|stop|restart|status|health|doctor|stats|vault-scan|search|ask|storage-check|ollama-check|sync|watch|index|export|diagnostics|api|cag|api-key|preflight-secrets|rotate-api-key|deploy-safe|remote|vram-audit|vram-check|vram-clear|vram-profile|llama-cpp|provider>"
         exit 1
         ;;
    esac
    ;;

  graph)
    if [[ "${#extra_args[@]}" -eq 0 ]]; then
      graph_sub="help"
    else
      graph_sub="${extra_args[0]}"
      extra_args=("${extra_args[@]:1}")
    fi

    case "$graph_sub" in
      status)
        kryonix_graph_status "${extra_args[@]}"
        ;;
      schema)
        kryonix_graph_schema "${extra_args[@]}"
        ;;
      ingest)
        kryonix_graph_ingest "${extra_args[@]}"
        ;;
      ingest-registry)
        kryonix_graph_ingest_registry "${extra_args[@]}"
        ;;
      query)
        if [[ "${#extra_args[@]}" -eq 0 ]]; then
          kryonix_graph_query_usage
          exit 2
        fi
        kryonix_graph_query "${extra_args[@]}"
        ;;
      examples)
        kryonix_graph_examples
        ;;
      doctor)
        kryonix_graph_doctor "${extra_args[@]}"
        ;;
      stats)
        kryonix_graph_stats "${extra_args[@]}"
        ;;
      top)
        kryonix_graph_top "${extra_args[@]}"
        ;;
      heal)
        kryonix_graph_server_only heal "${extra_args[@]}"
        ;;
      repair)
        kryonix_graph_server_only repair "${extra_args[@]}"
        ;;
      *)
        printf 'Uso: kryonix graph <status|schema|ingest|ingest-registry|query|examples|doctor|stats|top|heal|repair> [--remote|--local]\n' >&2
        exit 1
        ;;
    esac
    ;;

  mcp)
    if [[ "${#extra_args[@]}" -eq 0 ]]; then
      mcp_sub="print-config"
    else
      mcp_sub="${extra_args[0]}"
      extra_args=("${extra_args[@]:1}")
    fi

    case "$mcp_sub" in
      check)
        kryonix_mcp_check "${extra_args[@]}"
        ;;
      doctor)
        kryonix_mcp_doctor "${extra_args[@]}"
        ;;
      print-config)
        print_mcp_config
        ;;
      *)
        printf 'Usage: kryonix mcp <check|doctor|print-config>\n' >&2
        exit 1
        ;;
    esac
    ;;

  vault)
    if [[ "${#extra_args[@]}" -eq 0 ]]; then
      printf 'Uso: kryonix vault <scan|index|curate|sync-docs>\n' >&2
      exit 1
    fi
    vault_sub="${extra_args[0]}"
    extra_args=("${extra_args[@]:1}")

    case "$vault_sub" in
      scan)
        kryonix_brain_vault_scan "${extra_args[@]}"
        ;;
      index|curate|sync-docs)
        run_brain_cli vault "$vault_sub" "${extra_args[@]}"
        ;;
      *)
        printf 'Uso: kryonix vault <scan|index|curate|sync-docs>\n' >&2
        exit 1
        ;;
    esac
    ;;

  ollama)
    kryonix_ollama "${extra_args[@]}"
    ;;

  ai)
    kryonix_ai "${extra_args[@]}"
    ;;

  remote)
    kryonix_remote "${extra_args[@]}"
    ;;

  install)
    kryonix_install "${extra_args[@]}"
    ;;

  hardware)
    case "${extra_args[0]:-}" in
      scan) kryonix_hardware_scan "${extra_args[@]:1}" ;;
      *) kryonix_hardware_scan "${extra_args[@]}" ;;
    esac
    ;;

  disk)
    case "${extra_args[0]:-}" in
      list) kryonix_disk_list "${extra_args[@]:1}" ;;
      plan) kryonix_disk_plan "${extra_args[@]:1}" ;;
      *) kryonix_disk_list "${extra_args[@]}" ;;
    esac
    ;;

  *)
    printf 'Comando desconhecido: %s\n\n' "$subcommand" >&2
    print_usage >&2
    exit 1
    ;;
esac
