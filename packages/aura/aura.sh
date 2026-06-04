# =============================================================================
# aura — camada Kryonix por cima do motor Hermes (NousResearch, flake input).
#
# NÃO toca no código do Hermes. Roteia entre providers (Claude → Gemini →
# Codex/OpenAI) classificando o erro, e chama o comando `hermes` (wrapper do
# módulo NixOS), que cuida do venv/env. Segredos só via HERMES_ENV; nunca logados.
#
# Subcomandos:
#   aura [mensagem...]            chat/oneshot roteado (fallback automático)
#   aura providers list          lista providers e se a chave está presente
#   aura providers doctor        diagnóstico (chaves + hermes doctor), sem vazar
#   aura providers test <p>      teste mínimo de um provider
#   aura config show|path        mostra/aponta a config canônica
# =============================================================================
set -uo pipefail

HERMES_CONFIG="${HERMES_CONFIG:-/etc/kryonix/hermes/config.yaml}"
HERMES_ENV="${HERMES_ENV:-/etc/kryonix/hermes.env}"
export HERMES_CONFIG HERMES_ENV

# Carrega secrets (chaves) — só em memória do processo; nunca ecoadas.
if [ -r "$HERMES_ENV" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$HERMES_ENV"
  set +a
fi

PRIMARY="${HERMES_PROVIDER_PRIMARY:-claude}"
FALLBACKS="${HERMES_PROVIDER_FALLBACKS:-gemini,codex,openai}"

# Modelos por provider — configuráveis por env (NÃO inventar ids: ajuste no
# hermes.env/config.yaml conforme o catálogo real do `hermes`).
MODEL_CLAUDE="${AURA_MODEL_CLAUDE:-claude-sonnet-4-5}"
MODEL_GEMINI="${AURA_MODEL_GEMINI:-gemini-2.5-flash}"
MODEL_CODEX="${AURA_MODEL_CODEX:-gpt-5-codex}"
MODEL_OPENAI="${AURA_MODEL_OPENAI:-gpt-4o}"

# provider → (nome --provider do hermes, modelo, nome da env key)
provider_hprovider() { case "$1" in
  claude) echo anthropic ;; gemini) echo google ;; codex) echo codex ;; openai) echo openai ;; *) echo "$1" ;;
esac; }
provider_model() { case "$1" in
  claude) echo "$MODEL_CLAUDE" ;; gemini) echo "$MODEL_GEMINI" ;; codex) echo "$MODEL_CODEX" ;; openai) echo "$MODEL_OPENAI" ;; *) echo "" ;;
esac; }
# Retorna 0 se há chave; ecoa o NOME da env usada (nunca o valor).
provider_keyname() {
  case "$1" in
    claude) [ -n "${ANTHROPIC_API_KEY:-}" ] && { echo ANTHROPIC_API_KEY; return 0; }; echo "ANTHROPIC_API_KEY"; return 1 ;;
    gemini) [ -n "${GEMINI_API_KEY:-}" ] && { echo GEMINI_API_KEY; return 0; }
            [ -n "${GOOGLE_API_KEY:-}" ] && { echo GOOGLE_API_KEY; return 0; }; echo "GEMINI_API_KEY/GOOGLE_API_KEY"; return 1 ;;
    codex)  [ -n "${CODEX_API_KEY:-}" ] && { echo CODEX_API_KEY; return 0; }
            [ -n "${OPENAI_API_KEY:-}" ] && { echo OPENAI_API_KEY; return 0; }; echo "CODEX_API_KEY/OPENAI_API_KEY"; return 1 ;;
    openai) [ -n "${OPENAI_API_KEY:-}" ] && { echo OPENAI_API_KEY; return 0; }; echo "OPENAI_API_KEY"; return 1 ;;
    *) echo "?"; return 1 ;;
  esac
}

order() { printf '%s\n' "$PRIMARY"; printf '%s' "$FALLBACKS" | tr ',' '\n'; }

# Classifica o texto de erro do provider. Ecoa: fallback | stop | context | ok
classify_error() {
  local t; t="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$t" in
    *invalid_api_key*|*"invalid api key"*|*unauthorized*|*" 401"*|*permission_denied*|*forbidden*|*" 403"*|*safety*|*"blocked"*|*malformed*|*"invalid request"*|*"bad request"*|*" 400"*) echo stop ;;
    *context_length*|*"context length"*|*"maximum context"*|*"too many tokens"*|*"reduce the length"*) echo context ;;
    *rate*limit*|*" 429"*|*quota*|*temporar*|*timeout*|*"timed out"*|*overloaded*|*server_error*|*"internal server error"*|*" 500"*|*" 502"*|*" 503"*) echo fallback ;;
    *) echo unknown ;;
  esac
}

run_provider() {
  # $1 provider; restante = args do hermes. Ecoa saída; retorna exit do hermes.
  local p="$1"; shift
  local hp model; hp="$(provider_hprovider "$p")"; model="$(provider_model "$p")"
  hermes --provider "$hp" -m "$model" "$@"
}

cmd_chat() {
  local providers; mapfile -t providers < <(order)
  local tried=0
  for p in "${providers[@]}"; do
    [ -z "$p" ] && continue
    local keyname; if ! keyname="$(provider_keyname "$p")"; then
      echo "Provider $p ignorado: $keyname ausente." >&2
      continue
    fi
    tried=$((tried+1))
    local attempts=0
    while [ "$attempts" -lt 2 ]; do
      attempts=$((attempts+1))
      local out rc
      out="$(run_provider "$p" "$@" 2>&1)"; rc=$?
      if [ "$rc" -eq 0 ]; then
        printf '%s\n' "$out"
        return 0
      fi
      local verdict; verdict="$(classify_error "$out")"
      case "$verdict" in
        stop)
          echo "Provider $p falhou com erro não-recuperável; não faço fallback." >&2
          printf '%s\n' "$out" >&2
          return "$rc" ;;
        context)
          # Hermes já compacta nativamente (enable_context_compaction). Se ainda
          # estourou, a compactação não resolveu → vai pro próximo provider.
          echo "$p: context_length_exceeded mesmo após compactação nativa. Alternando." >&2
          break ;;
        fallback)
          echo "$p indisponível por rate_limit/quota/timeout/server_error. Aura alternando para o próximo provider." >&2
          break ;;
        *)
          if [ "$attempts" -ge 2 ]; then
            echo "$p: erro não classificado após $attempts tentativas; alternando." >&2
            printf '%s\n' "$out" >&2
            break
          fi
          sleep 2 ;;
      esac
    done
  done
  if [ "$tried" -eq 0 ]; then
    echo "Nenhum provider disponível: configure chaves em $HERMES_ENV." >&2
  else
    echo "Todos os providers tentados falharam." >&2
  fi
  return 1
}

cmd_providers() {
  case "${1:-list}" in
    list)
      local providers; mapfile -t providers < <(order)
      for p in "${providers[@]}"; do
        [ -z "$p" ] && continue
        local kn st; if kn="$(provider_keyname "$p")"; then st="chave OK ($kn)"; else st="SEM chave ($kn)"; fi
        printf '  %-8s -> hermes:%-10s modelo:%-18s [%s]\n' "$p" "$(provider_hprovider "$p")" "$(provider_model "$p")" "$st"
      done ;;
    doctor)
      echo "== Aura providers doctor =="
      echo "Config:  $HERMES_CONFIG  ($( [ -r "$HERMES_CONFIG" ] && echo presente || echo AUSENTE ))"
      echo "Env:     $HERMES_ENV     ($( [ -r "$HERMES_ENV" ] && echo presente || echo 'ausente/sem-leitura' ))"
      echo "Primary: $PRIMARY   Fallbacks: $FALLBACKS"
      cmd_providers list
      echo "-- hermes doctor --"
      hermes doctor 2>&1 | sed 's/\(KEY\|TOKEN\|SECRET\)=[^ ]*/\1=***/Ig' || true ;;
    test)
      local p="${2:?uso: aura providers test <claude|gemini|codex|openai>}"
      local kn; if ! kn="$(provider_keyname "$p")"; then echo "Provider $p: $kn ausente."; return 1; fi
      echo "Testando $p (hermes:$(provider_hprovider "$p") / $(provider_model "$p"))..."
      if printf 'responda apenas: OK' | run_provider "$p" >/dev/null 2>&1; then
        echo "$p: OK"
      else
        echo "$p: FALHOU (ver chave/modelo/cota)"; return 1
      fi ;;
    *) echo "uso: aura providers {list|doctor|test <p>}" >&2; return 2 ;;
  esac
}

case "${1:-}" in
  providers) shift; cmd_providers "$@" ;;
  config)
    case "${2:-show}" in
      path) echo "$HERMES_CONFIG" ;;
      show) [ -r "$HERMES_CONFIG" ] && cat "$HERMES_CONFIG" || echo "config ausente: $HERMES_CONFIG" ;;
      *) echo "uso: aura config {show|path}" >&2; exit 2 ;;
    esac ;;
  ""|-h|--help)
    echo "Aura (camada Kryonix sobre Hermes). Uso:"
    echo "  aura <mensagem>            chat roteado (Claude->Gemini->Codex/OpenAI)"
    echo "  aura providers list|doctor|test <p>"
    echo "  aura config show|path"
    [ "${1:-}" = "" ] && exit 0 || exit 0 ;;
  *) cmd_chat "$@" ;;
esac
