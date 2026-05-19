#!/usr/bin/env bash
# =============================================================================
# Kora CLI Wrapper
#
# Integra a assistente Kora ao wrapper oficial `kryonix`.
# Gerencia auth, URLs e modo local/remoto automaticamente.
# =============================================================================

kora_api_url() {
  local url="${KORA_API_URL:-}"
  if [[ -z "$url" ]]; then
    # Se estamos no Glacier (server), a Kora roda no localhost
    if [[ "$(map_runtime_host)" == "glacier" ]]; then
      url="http://127.0.0.1:8787"
    else
      # Se estamos no Inspiron (client), a Kora é acessada via rede
      # Tenta DNS (Tailscale) primeiro, fallback para IP local
      # Aumentado timeout para 2.0s devido a possíveis latências de wake-up do Tailscale
      if timeout 2.0 ping -c 1 rve-glacier >/dev/null 2>&1; then
        url="http://rve-glacier:8787"
      else
        url="http://10.0.0.2:8787"
      fi
    fi
  fi
  printf '%s\n' "${url%/}"
}

export_kora_env() {
  # 1. Tenta carregar do config local do usuário (preferencial para clientes)
  local user_config="$HOME/.config/kryonix/kora.env"
  if [[ -f "$user_config" ]] && [[ -r "$user_config" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$user_config"
    set +a
  fi

  # 2. Tenta carregar do config global (preferencial para o servidor)
  if [[ -f "/etc/kryonix/kora.env" ]] && [[ -r "/etc/kryonix/kora.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "/etc/kryonix/kora.env"
    set +a
  fi
}

kora_is_offline() {
  local url
  url="$(kora_api_url)"
  if ! curl -sS --max-time 2 -o /dev/null "$url/health"; then
    return 0 # Offline
  fi
  return 1 # Online
}

kora_curl() {
  local method="$1"
  local path="$2"
  local data="${3:-}"
  local url
  local -a curl_args
  local api_key

  export_kora_env
  url="$(kora_api_url)"
  api_key="${KORA_API_KEY:-}"

  curl_args=(--connect-timeout 5 --max-time 120 -X "$method" -H "Accept: application/json")

  if [[ -n "$data" ]] || [[ "$method" == "POST" ]] || [[ "$method" == "PUT" ]]; then
    curl_args+=(-H "Content-Type: application/json")
  fi

  if [[ -n "$api_key" ]]; then
    curl_args+=(-H "X-API-Key: $api_key")
  fi

  if [[ -n "$data" ]]; then
    curl_args+=(--data "$data")
  fi

  if kora_is_offline; then
    if [[ "$(map_runtime_host)" == "glacier" ]]; then
      printf 'ERRO: Kora API local (%s) não está ativa.\n' "$url" >&2
      printf 'Use: systemctl status kora.service\n' >&2
    else
      printf 'WARN: Kora API remota não acessível em %s\n' "$url" >&2
      printf 'Dica: Abra o túnel SSH no Inspiron com:\n' >&2
      printf '      kryonix kora tunnel\n' >&2
    fi
    return 2
  fi

  local tmp_resp http_code status
  tmp_resp=$(mktemp)

  http_code=$(curl -sS -w "%{http_code}" -o "$tmp_resp" "${curl_args[@]}" "$url$path")
  status=$?

  if [[ $status -ne 0 ]]; then
    printf 'ERRO: Falha ao conectar ao servidor Kora (%s)\n' "$status" >&2
    rm -f "$tmp_resp"
    return "$status"
  fi

  if [[ "$http_code" == "401" ]] || [[ "$http_code" == "403" ]]; then
    printf 'ERRO: endpoint protegido. Defina KORA_API_KEY.\n' >&2
    rm -f "$tmp_resp"
    return 1
  elif [[ "$http_code" -ge 400 ]]; then
    printf 'ERRO: A Kora retornou status HTTP %s.\n' "$http_code" >&2
    cat "$tmp_resp" >&2
    printf '\n' >&2
    rm -f "$tmp_resp"
    return 1
  fi

  cat "$tmp_resp"
  printf '\n'
  rm -f "$tmp_resp"
  return 0
}

kora_stream() {
  local method="$1"
  local path="$2"
  local data="${3:-}"
  local url
  local -a curl_args
  local api_key

  export_kora_env
  url="$(kora_api_url)"
  api_key="${KORA_API_KEY:-}"

  curl_args=(--no-buffer --connect-timeout 5 --max-time 300 -sS -X "$method" -H "Accept: text/event-stream")

  if [[ -n "$data" ]] || [[ "$method" == "POST" ]]; then
    curl_args+=(-H "Content-Type: application/json")
    curl_args+=(--data "$data")
  fi

  if [[ -n "$api_key" ]]; then
    curl_args+=(-H "X-API-Key: $api_key")
  fi

  curl "${curl_args[@]}" "$url$path"
}

# ── Animação de Pensamento (Kora Neural) ────────────────────────
# Visual minimalista e sofisticado para o CLI.

KORA_THINK_FRAMES=("⠋⟡" "⠙✦" "⠹✧" "⠸✦" "⠼✧" "⠴✦" "⠦⟡" "⠧✧")

kora_supports_animation() {
  [[ -t 1 ]] || return 1
  [[ "${KORA_JSON:-}" == "1" ]] && return 1
  [[ "${KORA_NO_ANIMATION:-}" == "1" ]] && return 1
  [[ "${CI:-}" == "true" ]] && return 1
  return 0
}

kora_think_start() {
  kora_supports_animation || return 0
  local start_time="$1"
  local frames=("${KORA_THINK_FRAMES[@]}")

  (
    local i=0
    # Garante limpeza se o subshell for morto
    trap "tput el; exit" SIGINT SIGTERM

    while true; do
      local now
      now=$(date +%s.%N)
      local elapsed
      elapsed=$(echo "$now - $start_time" | bc 2>/dev/null | sed 's/^\./0./; s/^-\./-0./' || echo "0")

      printf "\r\e[2m\e[K" >&2
      LC_NUMERIC=C printf "\e[1;36mKORA\e[0m  \e[33m%s\e[0m  \e[2m%.1fs\e[0m" "${frames[$((i % ${#frames[@]}))]}" "$elapsed" >&2

      i=$((i + 1))
      sleep 0.12
    done
  ) &
  KORA_THINK_PID=$!
  return 0
}

kora_think_stop() {
  if [[ -n "${KORA_THINK_PID:-}" ]]; then
    kill "$KORA_THINK_PID" 2>/dev/null && wait "$KORA_THINK_PID" 2>/dev/null
    unset KORA_THINK_PID
  fi
  if kora_supports_animation; then
    printf "\r\e[K" >&2
  fi
  return 0
}

kora_print_timing() {
  local total="$1"
  local first_token="$2"
  local mode="$3"
  local endpoint="$4"

  printf "\n\e[2mtiming: total=%.2fs" "$total"
  [[ -n "$first_token" ]] && printf " first_token=%.2fs" "$first_token"
  printf " endpoint=%s mode=%s\e[0m\n" "$endpoint" "$mode"
}

kryonix_kora_health() {
  kora_curl GET /health | jq .
}

kryonix_kora_status() {
  printf "Kora System Status:\n"
  kora_curl GET /health | jq -r '"Health: \(.status) (v\(.version))"' || echo "API Indisponível"

  printf "\nMemory Status:\n"
  local mem index
  mem=$(kora_curl GET /memory/status)
  index=$(kora_curl GET /memory/index/status)

  if [[ -n "$mem" ]]; then
    echo "$mem" | jq -r '
      "  Queue:    \(.queue.pending_items) items",
      "  Vault:    \(.vault.path) (exists: \(.vault.exists))"
    '
  fi

  if [[ -n "$index" ]]; then
    echo "$index" | jq -r '
      "  Index:    \(.indexed_files)/\(.total_files_in_manifest) files (\(.status))",
      "  Pending:  \(.pending_approval) propostas"
    '
  fi
}

kryonix_kora_capabilities() {
  kora_curl GET /capabilities | jq .
}

kryonix_kora_ask() {
  local mode="auto"
  local model=""
  local profile="${KORA_PROFILE:-0}"
  local start_time
  start_time=$(date +%s.%N)
  local query_parts=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode)
        mode="$2"
        shift 2
        ;;
      --model)
        model="$2"
        shift 2
        ;;
      --profile)
        profile=1
        shift
        ;;
      --*)
        # Unknown flag, treat as part of query or skip?
        # For safety, treat unknown -- flags as potential query parts if they are not known,
        # but here we follow the standard: if it's a flag, it's a param.
        shift
        ;;
      *)
        query_parts+=("$1")
        shift
        ;;
    esac
  done

  local query="${query_parts[*]}"

  if [[ -z "$query" ]]; then
    printf 'Erro: Você precisa fornecer uma pergunta ou comando.\n' >&2
    printf 'Uso: kryonix kora [ask] <pergunta> [--mode auto|direct|rag] [--model <modelo>]\n' >&2
    return 1
  fi

  # Configuração de contexto para animação
  export KORA_JSON="${KORA_JSON:-0}"

  # Inicia animação se suportado
  kora_think_start "$start_time"
  trap 'kora_think_stop' EXIT INT TERM

  # Variáveis para profiling
  local first_token_time=""
  local endpoint="/chat"
  local payload
  local current_user
  current_user="$(whoami)"
  payload="$(jq -n \
    --arg question "$query" \
    --arg message "$query" \
    --arg mode "$mode" \
    --arg user "$current_user" \
    --arg model "${model:-}" \
    '{question:$question, message:$message, mode:$mode, user:$user, model:(if $model != "" then $model else null end)}')"

  # Stream if mode is auto or direct and TTY
  if [[ ("$mode" == "direct" || "$mode" == "auto") && -t 1 && "${KORA_JSON}" != "1" ]]; then
    endpoint="/chat/stream"
    local first=1

    while read -r line; do
      if [[ "$line" == data:\ * ]]; then
        local chunk_data="${line#data: }"
        local type
        type=$(echo "$chunk_data" | jq -r '.type // empty')

        if [[ "$type" == "meta" ]]; then
            # Metadata can be ignored or used for profile
            continue
        fi

        if [[ "$type" == "content" ]]; then
          if [[ $first -eq 1 ]]; then
            kora_think_stop
            printf "\e[1;36mKora:\e[0m\n"
            first=0
            first_token_time=$(date +%s.%N)
          fi
          local text
          text=$(echo "$chunk_data" | jq -r '.chunk // empty')
          [[ -n "$text" ]] && printf "%s" "$text"
        fi

        if [[ "$type" == "action" ]]; then
          local proposal
          proposal=$(echo "$chunk_data" | jq -r '.proposal')
          printf "\n\n\e[1;33mProposta de Ação:\e[0m %s\n" "$(echo "$proposal" | jq -r '.reason // .command // .action')"
          if [[ "$(echo "$proposal" | jq -r '.requires_confirmation')" == "true" ]]; then
              printf "\e[1;33mConfirme com:\e[0m kora confirmar\n"
          fi
        fi
      fi
    done < <(kora_stream POST "$endpoint" "$payload")
    printf "\n"
  else
    # Block mode
    local resp
    resp="$(kora_curl POST "$endpoint" "$payload")"
    local status=$?

    kora_think_stop

    if [[ $status -ne 0 ]]; then
      return $status
    fi

    if [[ "${KORA_JSON}" == "1" ]]; then
      printf "%s\n" "$resp"
    else
      printf "\e[1;36mKora:\e[0m\n"
      printf "%s\n" "$resp" | jq -r '.answer // "Erro ao obter resposta."'

      local action
      action=$(printf "%s\n" "$resp" | jq -r '.action // empty')
      if [[ -n "$action" && "$action" != "null" ]]; then
          printf "\n\e[1;33mProposta de Ação:\e[0m %s\n" "$(echo "$action" | jq -r '.reason // .command // .action')"
          if [[ "$(echo "$action" | jq -r '.requires_confirmation')" == "true" ]]; then
              printf "\e[1;33mConfirme com:\e[0m kora confirmar\n"
          fi
      fi
    fi
  fi

  # Profile final
  if [[ $profile -eq 1 ]]; then
    local end_time
    end_time=$(date +%s.%N)
    local total_elapsed
    total_elapsed=$(echo "$end_time - $start_time" | bc 2>/dev/null | sed 's/^\./0./; s/^-\./-0./' || echo "0")

    local ft_elapsed=""
    if [[ -n "$first_token_time" ]]; then
      ft_elapsed=$(echo "$first_token_time - $start_time" | bc 2>/dev/null | sed 's/^\./0./; s/^-\./-0./' || echo "0")
    fi

    LC_NUMERIC=C kora_print_timing "$total_elapsed" "$ft_elapsed" "$mode" "$endpoint"
  fi
}

kryonix_kora_chat() {
  printf 'WARN: O modo chat interativo será implementado na Fase 3.\n' >&2
  printf '      Para uma pergunta única, use: kryonix kora ask "sua pergunta"\n' >&2
  return 0
}

kryonix_kora_memory_search() {
  local query="$1"
  if [[ -z "$query" ]]; then
    printf 'Uso: kryonix kora memory search "termo"\n' >&2
    return 1
  fi

  local payload
  payload="$(jq -n --arg query "$query" --arg mode "hybrid" '{query:$query, mode:$mode}')"
  kora_curl POST /memory/search "$payload" | jq .
}

kryonix_kora_memory_status() {
  kora_curl GET /memory/status | jq .
}

kryonix_kora_memory_recent() {
  local limit="${1:-10}"
  kora_curl GET "/memory/recent?limit=$limit" | jq .
}

kryonix_kora_memory_flush() {
  printf 'Forçando processamento da fila de memória...\n'
  kora_curl POST /memory/flush | jq .
}

kryonix_kora_memory_index() {
  if [[ "$1" == "status" ]]; then
    kora_curl GET /memory/index/status | jq .
  elif [[ "$1" == "pending" ]]; then
    kora_curl GET /memory/index/pending | jq .
  else
    printf 'Iniciando indexação incremental das memórias no Brain...\n'
    kora_curl POST /memory/index | jq .
  fi
}

kryonix_kora_voice() {
    local sub="${1:-devices}"
    shift || true

    case "$sub" in
        devices)
            kora-admin voice devices
            ;;
        test-mic)
            kora-admin voice test-mic "$@"
            ;;
        transcribe)
            kora-admin voice transcribe "$@"
            ;;
        speak)
            kora-admin voice speak "$@"
            ;;
        identity)
            kora-admin voice identity "$@"
            ;;
        daemon)
            shift
            kora-admin voice daemon "$@"
            ;;
        mute)
            kora-admin voice daemon stop # Fallback for now
            ;;
        unmute)
            kora-admin voice daemon start # Fallback for now
            ;;
        *)
            printf 'Uso: kryonix kora voice [devices|test-mic|transcribe|speak|identity|daemon|mute|unmute]\n' >&2
            return 1
            ;;
    esac
}

kryonix_kora_listen() {
    kora-admin listen "$@"
}

kryonix_kora_audit() {
    local sub="${1:-benchmark}"
    shift || true

    case "$sub" in
        benchmark)
            kora-admin benchmark "$@"
            ;;
        grounding)
            kora-admin audit grounding "$@"
            ;;
        *)
            printf 'Uso: kryonix kora audit [benchmark|grounding]\n' >&2
            return 1
            ;;
    esac
}

kryonix_kora_login() {
  if [[ "$(map_runtime_host)" == "glacier" ]]; then
    printf 'INFO: Você já está no servidor Glacier. A chave em /etc/kryonix/kora.env será usada.\n'
    return 0
  fi

  local ssh_target="${KRYONIX_GLACIER_SSH_TARGET:-rocha@rve-glacier}"
  local ssh_port="${KRYONIX_GLACIER_SSH_PORT:-2224}"
  local remote_env="/etc/kryonix/kora.env"
  local local_config_dir="$HOME/.config/kryonix"
  local local_env="$local_config_dir/kora.env"

  mkdir -p "$local_config_dir"
  chmod 700 "$local_config_dir"

  printf 'Sincronizando Kora API Key do Glacier (%s)...\n' "$ssh_target"

  # Busca a chave via SSH e salva direto no arquivo local com permissão restrita
  # Redireciona a saída do SSH para o arquivo local diretamente para evitar prints no terminal
  if ! ssh -p "$ssh_port" "$ssh_target" "sudo grep '^KORA_API_KEY=' $remote_env" > "$local_env" 2>/dev/null; then
    printf 'ERRO: Não foi possível obter a chave via SSH. Verifique o acesso.\n' >&2
    rm -f "$local_env"
    return 1
  fi

  chmod 600 "$local_env"

  # Valida se a chave foi capturada (sem mostrar o valor)
  if ! grep -q "KORA_API_KEY=" "$local_env"; then
    printf 'ERRO: Arquivo de chave obtido está vazio ou inválido.\n' >&2
    rm -f "$local_env"
    return 1
  fi

  local key_len fingerprint
  key_len=$(grep "KORA_API_KEY=" "$local_env" | cut -d= -f2 | tr -d '\n' | wc -c)
  fingerprint=$(grep "KORA_API_KEY=" "$local_env" | cut -d= -f2 | head -c 8)

  printf 'OK: Chave sincronizada e salva em %s\n' "$local_env"
  printf '    Fingerprint: %s... (tamanho: %s)\n' "$fingerprint" "$key_len"
  printf '    Permissões: %s\n' "$(stat -c "%a" "$local_env")"
}

kryonix_kora_latency() {
  printf "Kora Latency Diagnostics:\n"

  printf "1. Direct (Stream)...\n"
  KORA_PROFILE=1 kryonix_kora_ask "explique NixOS em uma frase" --mode direct

  printf "\n2. Auto (Smart Routing)...\n"
  KORA_PROFILE=1 kryonix_kora_ask "quem é você?" --mode auto

  printf "\n3. RAG (Knowledge)...\n"
  KORA_PROFILE=1 kryonix_kora_ask "arquitetura do Glacier" --mode rag

  printf "\nRecomendação:\n"
  printf "- Default diário: direct_stream (via modo auto smart)\n"
  printf "- Usar RAG só para Kryonix/docs/memória\n"

  printf '\n4. Ollama Status:\n'
  if command -v ollama >/dev/null 2>&1; then
    ollama ps
  else
    printf 'Ollama CLI não encontrado localmente.\n'
  fi

  printf '\n\e[1;32mDiagnóstico concluído.\e[0m\n'
}

kryonix_kora_tunnel() {
  if [[ "$(map_runtime_host)" == "glacier" ]]; then
    printf 'INFO: O túnel não é necessário no Glacier, a Kora roda nativamente no localhost.\n' >&2
    return 0
  fi

  local ssh_target="${KRYONIX_GLACIER_SSH_TARGET:-glacier-public}"
  local ssh_port="${KRYONIX_GLACIER_SSH_PORT:-2224}"

  printf 'Abrindo túnel SSH para a Kora no Glacier...\n'
  printf 'Alvo: %s:%s\n' "$ssh_target" "$ssh_port"
  printf 'Local: http://127.0.0.1:18787\n'
  printf 'Pressione Ctrl+C para encerrar.\n\n'

  ssh -p "$ssh_port" -N -L 18787:127.0.0.1:8787 "$ssh_target"
}

kryonix_kora_help() {
  printf 'Kryonix Kora CLI\n'
  printf 'Uso: kryonix kora [comando] [argumentos]\n\n'
  printf 'Comandos:\n'
  printf '  ask <pergunta>      Faz uma pergunta à Kora (padrão)\n'
  printf '  listen              Inicia modo escuta (Voz)\n'
  printf '  voice <subcomando>  Gerenciamento de voz (devices, test-mic, transcribe, speak)\n'
  printf '  memory <subcomando> Operações de memória (search, status, recent, flush, index)\n'
  printf '  audit <subcomando>  Auditoria e benchmarks (benchmark, grounding)\n'
  printf '  status              Mostra o status geral do sistema\n'
  printf '  health              Verifica a saúde da API e serviços\n'
  printf '  capabilities        Lista as capacidades ativas\n'
  printf '  tunnel              Abre túnel SSH para o Glacier\n'
  printf '  login               Sincroniza KORA_API_KEY do Glacier\n'
  printf '  help                Mostra esta mensagem de ajuda\n'
}

kryonix_kora() {
  local sub="${1:-help}"
  shift || true

  case "$sub" in
    help|--help|-h)
      kryonix_kora_help
      ;;
    health)
      kryonix_kora_health "$@"
      ;;
    status)
      kryonix_kora_status "$@"
      ;;
    capabilities)
      kryonix_kora_capabilities "$@"
      ;;
    ask)
      kryonix_kora_ask "$@"
      ;;
    chat)
      kryonix_kora_chat "$@"
      ;;
    memory)
      if [[ "$1" == "search" ]]; then
        shift
        kryonix_kora_memory_search "$@"
      elif [[ "$1" == "status" ]]; then
        kryonix_kora_memory_status
      elif [[ "$1" == "recent" ]]; then
        shift
        kryonix_kora_memory_recent "$@"
      elif [[ "$1" == "flush" ]]; then
        shift
        kryonix_kora_memory_flush
      elif [[ "$1" == "index" ]]; then
        shift
        kryonix_kora_memory_index "$@"
      else
        printf 'Uso: kryonix kora memory [search|status|recent|flush|index]\n' >&2
        return 1
      fi
      ;;
    tunnel)
      kryonix_kora_tunnel
      ;;
    login)
      kryonix_kora_login
      ;;
    latency|doctor-latency)
      kryonix_kora_latency
      ;;
    confirmar|confirm)
      kryonix_kora_confirm "$@"
      ;;
    voice)
      kryonix_kora_voice "$@"
      ;;
    listen)
      kryonix_kora_listen "$@"
      ;;
    user)
      shift
      kora-admin user "$@"
      ;;
    audit|benchmark)
      kryonix_kora_audit "$@"
      ;;
    *)
      # Se não for um subcomando conhecido, trata como pergunta natural
      kryonix_kora_ask "$sub" "$@"
      ;;
  esac
}

kryonix_kora_confirm() {
  printf 'Confirmando ação pendente via Kora API...\n'

  local resp
  resp=$(kora_curl POST /confirm)
  local status=$?

  if [[ $status -ne 0 ]]; then
    return $status
  fi

  local run_status
  run_status=$(echo "$resp" | jq -r '.status')

  if [[ "$run_status" == "success" ]]; then
    printf '\e[1;32mOK: Comando executado com sucesso no servidor.\e[0m\n'
    echo "$resp" | jq -r '.stdout'
  elif [[ "$run_status" == "failed" ]]; then
    printf '\e[1;31mFALHA: O comando retornou erro (code: %s).\e[0m\n' "$(echo "$resp" | jq -r '.returncode')"
    echo "$resp" | jq -r '.stderr'
  else
    printf '\e[1;33mAVISO: %s\e[0m\n' "$(echo "$resp" | jq -r '.message // "Erro desconhecido"') "
  fi
}
