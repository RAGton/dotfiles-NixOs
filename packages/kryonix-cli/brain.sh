brain_project_dir() {
  local repo_root project_dir

  repo_root="$(kryonix_repo_root)" || return 1
  project_dir="$repo_root/packages/kryonix-brain-lightrag"

  if [[ ! -f "$project_dir/pyproject.toml" ]]; then
    printf '%s\n' "kryonix: Brain não encontrado em $project_dir." >&2
    return 1
  fi

  printf '%s\n' "$project_dir"
}

kryonix_brain_role() {
  local explicit lower

  explicit="${KRYONIX_ROLE:-${KRYONIX_BRAIN_ROLE:-}}"
  lower="$(printf '%s' "$explicit" | tr '[:upper:]' '[:lower:]')"
  case "$lower" in
    client|server)
      printf '%s\n' "$lower"
      return 0
      ;;
  esac

  case "$(map_runtime_host)" in
    glacier)
      printf '%s\n' "server"
      ;;
    *)
      printf '%s\n' "client"
      ;;
  esac
}

export_brain_env() {
  if [[ -f "/etc/kryonix/brain.env" ]] && [[ -r "/etc/kryonix/brain.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "/etc/kryonix/brain.env"
    set +a
  fi
  if [[ -f "$HOME/.config/kryonix/brain-remote.env" ]]; then
    set -a
    # shellcheck disable=SC1090,SC1091
    source "$HOME/.config/kryonix/brain-remote.env"
    set +a
  fi
  local role
  role="$(kryonix_brain_role)"
  export KRYONIX_ROLE="${KRYONIX_ROLE:-$role}"
  export KRYONIX_PROJECT_DIR="${KRYONIX_PROJECT_DIR:-/etc/kryonix}"
  export KRYONIX_STATE_ROOT="${KRYONIX_STATE_ROOT:-/var/lib/kryonix}"
  export KRYONIX_BRAIN_ROOT="${KRYONIX_BRAIN_ROOT:-/var/lib/kryonix/brain}"
  export KRYONIX_VAULT_DIR="${KRYONIX_VAULT_DIR:-/var/lib/kryonix/vault}"
  export LIGHTRAG_VAULT_DIR="${LIGHTRAG_VAULT_DIR:-/var/lib/kryonix/vault}"
  export LIGHTRAG_WORKING_DIR="${LIGHTRAG_WORKING_DIR:-/var/lib/kryonix/brain/storage}"
  export KRYONIX_BRAIN_STORAGE="${KRYONIX_BRAIN_STORAGE:-/var/lib/kryonix/brain/storage}"
  export LIGHTRAG_CAG_DIR="${LIGHTRAG_CAG_DIR:-/var/lib/kryonix/brain/cag}"
  export KRYONIX_CAG_DIR="${KRYONIX_CAG_DIR:-/var/lib/kryonix/brain/cag}"
  export KRYONIX_RAG_MANIFEST_DIR="${KRYONIX_RAG_MANIFEST_DIR:-/var/lib/kryonix/brain/rag/manifests}"
  export LD_LIBRARY_PATH="${runtimeLibPath}:${LD_LIBRARY_PATH:-}"
}

run_brain_cli() {
  local project_dir
  project_dir="$(brain_project_dir)" || return 1

  if [[ "$1" != "autopilot" ]] && [[ "$(kryonix_brain_role)" == "client" ]] && [[ "${KRYONIX_LOCAL_RAG_ENABLE:-}" != "true" ]]; then
    printf 'ERRO: O RAG local está desabilitado por padrão no cliente (Inspiron) para evitar duplicação de índices pesados.\n' >&2
    printf 'Para forçar a execução local, defina a variável: export KRYONIX_LOCAL_RAG_ENABLE=true\n' >&2
    return 1
  fi

  export_brain_env
  run_command uv run --project "$project_dir" python -m kryonix_brain_lightrag.cli "$@"
}

run_brain_rust_tool() {
  local tool_name="$1"
  shift
  local project_dir
  project_dir="$(brain_project_dir)" || return 1
  local bin_path="$project_dir/rust-core/target/debug/$tool_name"

  if [[ -x "$bin_path" ]]; then
    export LD_LIBRARY_PATH="${runtimeLibPath}:${LD_LIBRARY_PATH:-}"
    "$bin_path" "$@"
  else
    printf 'ERRO: Ferramenta Rust %s não encontrada ou não compilada.\n' "$tool_name" >&2
    printf 'Tente: nix-shell %s/shell.nix --run "cargo build --manifest-path %s/rust-core/Cargo.toml"\n' "$project_dir" "$project_dir" >&2
    return 1
  fi
}

run_brain_module() {
  local module project_dir
  module="$1"
  shift
  project_dir="$(brain_project_dir)" || return 1

  if [[ "$(kryonix_brain_role)" == "client" ]] && [[ "${KRYONIX_LOCAL_RAG_ENABLE:-}" != "true" ]]; then
    printf 'ERRO: Execução local do cérebro desabilitada no cliente (Inspiron).\n' >&2
    printf 'Para forçar a execução local, defina: export KRYONIX_LOCAL_RAG_ENABLE=true\n' >&2
    return 1
  fi

  export_brain_env
  run_command uv run --project "$project_dir" python -m "$module" "$@"
}

brain_api_url() {
  local url
  url="${KRYONIX_REMOTE_BRAIN_URL:-${KRYONIX_BRAIN_URL:-${KRYONIX_BRAIN_API:-}}}"
  if [[ -z "$url" ]] && [[ "$(kryonix_brain_role)" == "client" ]]; then
    # Tenta DNS primeiro, fallback para IP local se o DNS falhar ou estiver inacessível
    if timeout 0.5 ping -c 1 glacier-publico >/dev/null 2>&1; then
      url="http://glacier-publico:8000"
    else
      url="http://10.0.0.2:8000"
    fi
  fi
  printf '%s\n' "${url%/}"
}

brain_remote_required() {
  if [[ -z "$(brain_api_url)" ]]; then
    printf '%s\n' "Brain remoto não configurado. Defina KRYONIX_BRAIN_API." >&2
    return 2
  fi
}

brain_should_use_remote() {
  local mode="$1"

  case "$mode" in
    remote)
      return 0
      ;;
    local)
      return 1
      ;;
  esac

  if [[ "${KRYONIX_BRAIN_MODE:-}" == "remote" ]] || [[ "${KRYONIX_ROLE:-}" == "client" ]]; then
    return 0
  fi

  [[ -n "$(brain_api_url)" ]] && return 0
  [[ "$(kryonix_brain_role)" == "client" ]]
}

brain_remote_curl() {
  local method="$1"
  local path="$2"
  local data="${3:-}"
  local url
  local status
  local -a curl_args
  local api_key

  export_brain_env
  brain_remote_required || return $?
  url="$(brain_api_url)"
  api_key="${KRYONIX_BRAIN_API_KEY:-${KRYONIX_BRAIN_KEY:-}}"

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

  blue_line "Brain remoto: $method $url$path" >&2

  local tmp_resp http_code
  tmp_resp=$(mktemp)

  http_code=$(curl -sS -w "%{http_code}" -o "$tmp_resp" "${curl_args[@]}" "$url$path")
  status=$?

  if [[ $status -ne 0 ]]; then
    printf 'ERRO: Falha ao conectar ao servidor remoto (%s)\n' "$status" >&2
    rm -f "$tmp_resp"
    return "$status"
  fi

  if [[ "$http_code" == "403" ]]; then
    if [[ -z "$api_key" ]]; then
      printf 'ERRO: endpoint remoto protegido. Defina KRYONIX_BRAIN_API_KEY.\n' >&2
    else
      printf 'ERRO: endpoint remoto protegido. A chave fornecida em KRYONIX_BRAIN_API_KEY é inválida ou expirou.\n' >&2
    fi
    rm -f "$tmp_resp"
    return 1
  elif [[ "$http_code" -ge 400 ]]; then
    if jq -e '(.status == "missing_manifest") or (.detail.status == "missing_manifest")' "$tmp_resp" >/dev/null 2>&1; then
      printf 'ERRO: CAG manifest ausente no servidor remoto (HTTP %s).\n' "$http_code" >&2
      jq -r '
        (.detail // .) as $d
        | "Mensagem: " + ($d.message // "CAG manifest não encontrado.")
        , "Manifest: " + ($d.manifest_path // "desconhecido")
        , "Comandos recomendados:"
        , (($d.recommended_commands // [])[] | "  - " + .)
      ' "$tmp_resp" >&2
    else
      printf 'ERRO: O servidor remoto retornou status HTTP %s.\n' "$http_code" >&2
      cat "$tmp_resp" >&2
      printf '\n' >&2
    fi
    rm -f "$tmp_resp"
    return 1
  fi

  cat "$tmp_resp"
  printf '\n'
  rm -f "$tmp_resp"
  return 0
}

brain_local_curl() {
  local method="$1"
  local path="$2"
  local data="${3:-}"

  if ! curl -sS --max-time 2 -o /dev/null "http://127.0.0.1:8000/health"; then
    printf 'ERRO: Brain API local (127.0.0.1:8000) não está ativa.\n' >&2
    return 2
  fi

  export KRYONIX_REMOTE_BRAIN_URL="http://127.0.0.1:8000"
  brain_remote_curl "$method" "$path" "$data"
}

parse_brain_mode() {
  brain_mode="auto"
  brain_passthrough=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --local)
        brain_mode="local"
        ;;
      --remote)
        brain_mode="remote"
        ;;
      *)
        brain_passthrough+=("$1")
        ;;
    esac
    shift
  done
}

brain_safe_target_host() {
  printf '%s\n' "${flake_host:-$(map_runtime_host)}"
}

brain_safe_is_local_target() {
  local target="$1"
  [[ "$(map_runtime_host)" == "$target" ]]
}

brain_safe_ssh_target_for_host() {
  local target="$1"
  case "$target" in
    glacier)
      printf '%s\n' "${KRYONIX_GLACIER_SSH_TARGET:-rocha@rve-glacier}"
      ;;
    *)
      printf 'ERRO: deploy remoto do Brain só está definido para --host glacier.\n' >&2
      return 2
      ;;
  esac
}

brain_safe_remote_exec() {
  local sub="$1"
  shift
  local target ssh_target ssh_port remote_cmd

  target="$(brain_safe_target_host)"
  ssh_target="$(brain_safe_ssh_target_for_host "$target")" || return $?
  ssh_port="${KRYONIX_GLACIER_SSH_PORT:-2224}"

  local -a remote_args=(
    nix run git+file:///etc/kryonix#kryonix --
    brain "$sub" --host "$target" --local-exec "$@"
  )

  printf -v remote_cmd '%q ' "${remote_args[@]}"
  blue_line "Brain safe deploy: SSH $ssh_target:$ssh_port ($sub)"
  ssh -p "$ssh_port" -o BatchMode=yes -o ConnectTimeout=8 "$ssh_target" "cd /etc/kryonix && $remote_cmd"
}

brain_strip_local_exec_flag() {
  brain_local_exec=0
  brain_passthrough=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --local-exec)
        brain_local_exec=1
        ;;
      *)
        brain_passthrough+=("$1")
        ;;
    esac
    shift
  done
}

brain_should_run_remote_target() {
  local target
  target="$(brain_safe_target_host)"
  [[ "${brain_local_exec:-0}" -eq 0 ]] && ! brain_safe_is_local_target "$target"
}

brain_secret_scan_script() {
  local repo_root script
  repo_root="$(kryonix_repo_root)" || return 1
  script="$repo_root/scripts/kryonix-secret-scan.py"
  if [[ ! -f "$script" ]]; then
    printf 'ERRO: scanner não encontrado: %s\n' "$script" >&2
    return 1
  fi
  printf '%s\n' "$script"
}

kryonix_brain_preflight_secrets() {
  brain_strip_local_exec_flag "$@"
  if brain_should_run_remote_target; then
    brain_safe_remote_exec preflight-secrets "${brain_passthrough[@]}"
    return $?
  fi

  local repo_root scanner
  repo_root="$(kryonix_repo_root)" || return 1
  scanner="$(brain_secret_scan_script)" || return 1

  local -a scan_args=(--repo "$repo_root")
  local arg
  for arg in "${brain_passthrough[@]}"; do
    case "$arg" in
      --json|--quarantine-untracked)
        scan_args+=("$arg")
        ;;
      --help|-h)
        printf 'Uso: kryonix brain preflight-secrets [--json] [--quarantine-untracked] [--host glacier]\n'
        return 0
        ;;
      *)
        printf 'Opção desconhecida para preflight-secrets: %s\n' "$arg" >&2
        return 2
        ;;
    esac
  done

  python3 "$scanner" "${scan_args[@]}"
}

kryonix_graph_query_usage() {
  cat >&2 <<'EOF'
Uso: kryonix graph query [--cypher] 'MATCH ... RETURN ... LIMIT N'

graph query espera Cypher read-only, não pergunta natural em português.
LIMIT é obrigatório e operações de escrita são bloqueadas.

Exemplos:
  kryonix graph query --cypher 'MATCH (h:Host) RETURN h LIMIT 20'
  kryonix graph query --cypher 'MATCH (h:Host)-[:RUNS]->(s:Service) RETURN h, s LIMIT 20'
  kryonix graph query --cypher 'MATCH (s:Service)-[:LISTENS_ON]->(p:Port) RETURN s, p LIMIT 20'
EOF
}

kryonix_graph_examples() {
  cat <<'EOF'
Consultas GraphRAG read-only:

  kryonix graph query --cypher 'MATCH (h:Host) RETURN h LIMIT 20'
  kryonix graph query --cypher 'MATCH (h:Host)-[:RUNS]->(s:Service) RETURN h, s LIMIT 20'
  kryonix graph query --cypher 'MATCH (s:Service)-[:LISTENS_ON]->(p:Port) RETURN s, p LIMIT 20'
  kryonix graph query --cypher 'MATCH (f:File)-[:DECLARES]->(s:Service) RETURN f, s LIMIT 20'

Regras:
  - entrada deve ser Cypher read-only
  - LIMIT é obrigatório
  - CREATE, MERGE, DELETE, DETACH DELETE, SET, REMOVE, LOAD CSV, CALL dbms e CALL apoc são bloqueados
EOF
}

kryonix_graph_validate_cypher_query() {
  local q="$1"
  local q_upper
  local forbidden
  local -a forbidden_patterns

  q_upper="$(printf '%s' "$q" | tr '[:lower:]' '[:upper:]' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"

  forbidden_patterns=(
    "DETACH DELETE"
    "LOAD CSV"
    "CALL DBMS."
    "CALL APOC."
    "CREATE"
    "MERGE"
    "DELETE"
    "SET"
    "REMOVE"
  )

  for forbidden in "${forbidden_patterns[@]}"; do
    if [[ "$q_upper" == *"$forbidden"* ]]; then
      printf 'ERRO: padrão proibido em graph query read-only: %s\n' "$forbidden" >&2
      return 2
    fi
  done

  case "$q_upper" in
    MATCH*|OPTIONAL\ MATCH*|WITH*)
      ;;
    *)
      printf '%s\n' "ERRO: graph query atualmente espera Cypher read-only, não pergunta natural." >&2
      kryonix_graph_query_usage
      return 2
      ;;
  esac

  if ! [[ "$q_upper" =~ (^|[[:space:]])LIMIT([[:space:]]|$) ]]; then
    printf '%s\n' "ERRO: LIMIT obrigatório em graph query read-only." >&2
    printf '%s\n' "Exemplo: kryonix graph query --cypher 'MATCH (h:Host) RETURN h LIMIT 20'" >&2
    return 2
  fi
}

kryonix_brain_health() {
  parse_brain_mode "$@"
  if brain_should_use_remote "$brain_mode"; then
    if [[ "${KRYONIX_JSON_MODE:-}" == "1" ]]; then
      brain_remote_curl GET /health
      return $?
    else
      printf 'Brain remoto: GET %s/health\n' "$(brain_api_url)"
      brain_remote_curl GET /health
      return $?
    fi
  fi

  if [[ "$(kryonix_brain_role)" == "client" ]] && [[ "${KRYONIX_LOCAL_RAG_ENABLE:-}" != "true" ]]; then
    if [[ "${KRYONIX_JSON_MODE:-}" == "1" ]]; then
      printf '{"status": "LOCAL_DISABLED", "role": "client", "note": "RAG local desabilitado"}\n'
    else
      printf 'Kryonix Brain health (Local)\n'
      printf '  role:    client\n'
      printf '  status:  LOCAL_DISABLED\n'
      printf '  nota:    RAG local desabilitado para evitar duplicação do índice pesado.\n'
      printf '           Use --remote para consultar o Glacier, ou export KRYONIX_LOCAL_RAG_ENABLE=true para habilitar local.\n'
    fi
    return 0
  fi

  local project_dir
  project_dir="$(brain_project_dir)" || return 1
  export_brain_env

  run_command uv run --project "$project_dir" python -c "
import json
import os
from kryonix_brain_lightrag import config

health = {
    \"status\": \"OK\",
    \"project_dir\": str(config.PROJECT_DIR),
    \"vault_dir\": str(config.VAULT_DIR),
    \"working_dir\": str(config.WORKING_DIR),
    \"role\": os.environ.get(\"KRYONIX_ROLE\", \"server\")
}

if os.environ.get(\"KRYONIX_JSON_MODE\") == \"1\":
    print(json.dumps(health))
else:
    print(\"Kryonix Brain health (Local)\")
    print(f\"  project: {health['project_dir']}\")
    print(f\"  vault:   {health['vault_dir']}\")
    print(f\"  storage: {health['working_dir']}\")
    print(f\"  role:    {health['role']}\")
    print(f\"  status:  {health['status']}\")
"
}

kryonix_brain_doctor() {
  parse_brain_mode "$@"
  if brain_should_use_remote "$brain_mode"; then
    brain_remote_required || return $?
    if ! brain_remote_curl GET /health >/dev/null 2>&1; then
      blue_line "WARN: Brain remoto indisponível; runtime depende do Glacier."
      return 0
    fi

    local response
    response="$(brain_remote_curl GET /stats)" || return $?
    local cag_response
    cag_response="$(brain_remote_curl GET /cag/status)" || return $?

    local project_dir
    project_dir="$(brain_project_dir)" || return 1

    printf '%s|%s' "$response" "$cag_response" | uv run --project "$project_dir" python -c '
import sys, json
from rich.console import Console
from rich.panel import Panel
from rich.table import Table

try:
    raw = sys.stdin.read().split("|")
    stats = json.loads(raw[0])
    cag = json.loads(raw[1])
except Exception:
    print("Erro ao decodificar a resposta remota.")
    sys.exit(1)

console = Console()
console.print("\n[bold cyan][/bold cyan][black on cyan]KRYONIX BRAIN DOCTOR (REMOTE)[/black on cyan][bold cyan][/bold cyan]")

# RAG Integrity
integrity = stats.get("integrity", "OK")
color = "green" if "OK" in integrity else "yellow" if "WARNING" in integrity else "red"
console.print(Panel(f"[bold {color}]{integrity}[/bold {color}]", title="RAG Integrity", border_style=color))

# CAG Health
cag_status = cag.get("status", "unknown")
cag_freshness = cag.get("freshness", "unknown")
cag_ok = cag_status == "ok"

cag_msg = "CAG Ativo" if cag_ok else cag.get("message", "CAG Inativo")
cag_color = "green" if cag_ok else "red"
if cag_ok and cag_freshness == "STALE":
    cag_msg += " (STALE)"
    cag_color = "yellow"

console.print(Panel(f"[bold {cag_color}]{cag_msg}[/bold {cag_color}]", title="CAG Health", border_style=cag_color))

if not cag_ok:
    console.print("[dim]DICA: Execute \"kryonix brain cag build\" no servidor Glacier.[/dim]")
'
    return 0
  fi

  run_brain_cli doctor "${brain_passthrough[@]}"
}

kryonix_brain_stats() {
  parse_brain_mode "$@"
  if brain_should_use_remote "$brain_mode"; then
    if [[ "${KRYONIX_JSON_MODE:-}" == "1" ]]; then
      brain_remote_curl GET /stats
      return $?
    else
      local response
      response="$(brain_remote_curl GET /stats)" || return $?
      local project_dir
      project_dir="$(brain_project_dir)" || return 1
      printf '%s' "$response" | uv run --project "$project_dir" python -c '
import sys, json
from rich.console import Console
from rich.table import Table

try:
    data = json.load(sys.stdin)
except Exception:
    print("Erro ao decodificar a resposta remota.")
    sys.exit(1)

console = Console()
console.print("\n[bold magenta][/bold magenta][black on magenta]BRAIN REMOTE STATS[/black on magenta][bold magenta][/bold magenta]")
t = Table(show_header=True, header_style="bold magenta")
t.add_column("Métrica", style="cyan")
t.add_column("Contagem", style="green")
t.add_column("Detalhe / Status", style="dim")

t.add_row("Entidades", str(data.get("entities", 0)), "Mapeadas no Grafo")
t.add_row("Relações", str(data.get("relations", 0)), "Conexões semânticas")
t.add_row("Documentos", str(data.get("docs", 0)), "Arquivos indexados")
t.add_row("Consistência", str(data.get("consistency_status", "OK")), "Status do RAG")
t.add_row("Diretório Remoto", str(data.get("working_dir", "N/A")), "Storage no Glacier")

console.print(t)
'
      return $?
    fi
  fi

  run_brain_cli stats "${brain_passthrough[@]}"
}

kryonix_brain_vault_scan() {
  local vault_dir
  vault_dir="${KRYONIX_VAULT_DIR:-/home/rocha/.local/share/kryonix/kryonix-vault/vault}"

  # Tenta rodar a ferramenta Rust se compilada
  if [[ -x "$(brain_project_dir)/rust-core/target/debug/kryonix-vault-scan" ]]; then
    run_brain_rust_tool kryonix-vault-scan "$vault_dir" "$@"
  else
    # Fallback para Python
    run_brain_cli vault scan "$@"
  fi
}

kryonix_brain_search() {
  local action="$1"
  local query
  local payload
  local explain
  local -a query_parts

  shift
  parse_brain_mode "$@"
  if brain_should_use_remote "$brain_mode"; then
    explain="false"
    query_parts=()
    for arg in "${brain_passthrough[@]}"; do
      case "$arg" in
        --explain)
          explain="true"
          ;;
        *)
          query_parts+=("$arg")
          ;;
      esac
    done

    if [[ "${#query_parts[@]}" -eq 0 ]]; then
      printf 'Uso: kryonix brain %s "pergunta"\n' "$action" >&2
      return 2
    fi
    query="${query_parts[*]}"
    payload="$(jq -n --arg query "$query" --arg mode "hybrid" --arg intent "$action" --arg lang "pt-BR" --argjson explain "$explain" '{query:$query, mode:$mode, intent:$intent, lang:$lang, explain:$explain}')"

    if [[ "${KRYONIX_JSON_MODE:-}" == "1" ]]; then
      brain_remote_curl POST /search "$payload"
      return $?
    else
      local response
      response="$(brain_remote_curl POST /search "$payload")" || return $?
      local project_dir
      project_dir="$(brain_project_dir)" || return 1
      printf '%s' "$response" | uv run --project "$project_dir" python -c '
import sys, json
from rich.console import Console
from rich.markdown import Markdown
from rich.panel import Panel

try:
    data = json.load(sys.stdin)
except Exception:
    print("Erro ao decodificar a resposta remota.")
    sys.exit(1)

if data.get("status") == "success":
    console = Console()
    answer = data.get("answer", "")
    sources = data.get("sources", [])
    grounding = data.get("grounding", {})
    confidence = grounding.get("grounding_label") or grounding.get("confidence", "Normal")
    answerability = grounding.get("answerability")
    latency = grounding.get("latency_sec", 0.0)
    normalized = grounding.get("query_normalized")
    intent_label = data.get("intent") or grounding.get("intent", "n/a")
    mode_label = data.get("mode") or grounding.get("mode", "n/a")
    skipped = data.get("generation_skipped", False)
    provider = data.get("provider_used")
    tps = data.get("tps")

    if skipped:
        header_text = "🔎 [black on cyan]EVIDÊNCIAS LOCALIZADAS[/black on cyan]"
        border_style = "cyan"
        title_text = "[bold cyan]Kryonix Search (Remote)[/bold cyan]"
    else:
        header_text = "🧠 [black on magenta]RESPOSTA FUNDAMENTADA[/black on magenta]"
        border_style = "magenta"
        title_text = "[bold magenta]Kryonix Ask (Remote)[/bold magenta]"

    console.print(f"\n[bold {border_style}][/bold {border_style}]{header_text}[bold {border_style}][/bold {border_style}] [dim]Grounding: {confidence} ({latency}s)[/dim]")

    if answerability == "not_answerable" and grounding.get("retrieval_score", 0) > 0.7:
        console.print("[yellow]Similaridade alta, mas cobertura insuficiente da intenção da pergunta.[/yellow]")

    if normalized:
        # Novas métricas de Grounding vs Answerability (#39)
        r_score = grounding.get("retrieval_score", 0)
        a_score = grounding.get("answerability_score", 0)
        a_reason = grounding.get("answerability_reason", "")

        meta_info = f"[dim]Query normalizada: {normalized} | intent: {intent_label} | mode: {mode_label}"
        if not skipped and provider:
            meta_info += f" | provider: {provider}"
            if tps: meta_info += f" | tps: {tps}"
        meta_info += f" | Retrieval: {r_score}"

        if skipped:
            meta_info += " | Answerability: não sintetizada"
        else:
            meta_info += f" | Answerability: {a_score}"

        meta_info += "[/dim]"
        console.print(meta_info)

        if a_reason and a_score < 0.7:
             console.print(f"[yellow]⚠ {a_reason}[/yellow]")

    console.print(Panel(Markdown(answer), border_style=border_style, title=title_text, title_align="left"))

    if sources:
        limit = 10 if skipped else 5
        console.print(f"\n[bold {border_style}]Fontes usadas (Glacier RAG):[/bold {border_style}]")
        for i, src in enumerate(sources[:limit]):
            title = src.get("file") or src.get("title") or src.get("path") or "fonte desconhecida"
            score = src.get("score", "n/a")
            mode_used = src.get("mode") or "hybrid"
            console.print(f"  {i+1}. [bold white]{title}[/bold white] | score: {score} | modo: {mode_used}")
else:
    print(data.get("answer", "Erro desconhecido"))
'
      return $?
    fi
  fi

  run_brain_cli "$action" "${brain_passthrough[@]}"
}

kryonix_brain_normalize() {
  local query="$*"
  if [[ -z "$query" ]]; then
    printf 'Uso: kryonix brain normalize "pergunta"\n' >&2
    return 2
  fi

  parse_brain_mode "$@"
  if brain_should_use_remote "$brain_mode"; then
    local payload
    payload="$(jq -n --arg query "$query" '{query:$query}')"
    brain_remote_curl POST /normalize "$payload" | jq .
  else
    local project_dir
    project_dir="$(brain_project_dir)" || return 1
    export_brain_env
    run_command uv run --project "$project_dir" python -c "
import sys
from kryonix_brain_lightrag.query_utils import normalize_query_details
import json
print(json.dumps(normalize_query_details(\"$query\"), indent=2, ensure_ascii=False))
"
  fi
}

kryonix_graph_stats() {
  parse_brain_mode "$@"
  if brain_should_use_remote "$brain_mode"; then
    if [[ -z "$(brain_api_url)" ]]; then
      blue_line "WARN: Graph local existe no Glacier. Defina KRYONIX_BRAIN_API ou rode kryonix graph stats --local no servidor."
      return 0
    fi
    if ! brain_remote_curl GET /stats; then
      blue_line "WARN: Graph remoto indisponível; runtime depende do Glacier."
    fi
    return 0
  fi

  run_brain_cli stats "${brain_passthrough[@]}"
}

kryonix_graph_status() {
  parse_brain_mode "$@"
  if brain_should_use_remote "$brain_mode"; then
    brain_remote_curl GET /graph/status
    return $?
  fi
  brain_local_curl GET /graph/status
}

kryonix_graph_schema() {
  parse_brain_mode "$@"
  if brain_should_use_remote "$brain_mode"; then
    brain_remote_curl GET /graph/schema
    return $?
  fi
  brain_local_curl GET /graph/schema
}

kryonix_graph_ingest() {
  local mode="${1:-}"
  shift || true
  parse_brain_mode "$@"

  if ! brain_should_use_remote "$brain_mode"; then
    if ! curl -sS --max-time 2 -o /dev/null "http://127.0.0.1:8000/health"; then
      printf 'ERRO: Brain API local (127.0.0.1:8000) não está ativa.\n' >&2
      return 2
    fi
    export KRYONIX_REMOTE_BRAIN_URL="http://127.0.0.1:8000"
  fi

  case "$mode" in
    --dry-run)
      brain_remote_curl POST /graph/ingest/dry-run "{}"
      ;;
    --apply)
      local manifest_id="${brain_passthrough[0]:-}"
      if [[ -z "$manifest_id" ]]; then
        printf '%s\n' "Uso: kryonix graph ingest --apply <manifest_id>" >&2
        return 2
      fi
      local payload
      payload="$(jq -n --arg manifest_id "$manifest_id" '{manifest_id:$manifest_id}')"
      brain_remote_curl POST /graph/ingest/apply "$payload"
      ;;
    *)
      printf '%s\n' "Uso: kryonix graph ingest <--dry-run|--apply <manifest_id>> [--remote|--local]" >&2
      return 2
      ;;
  esac
}

kryonix_graph_ingest_registry() {
  local mode="${1:-}"
  shift || true
  parse_brain_mode "$@"

  if ! brain_should_use_remote "$brain_mode"; then
    if ! curl -sS --max-time 2 -o /dev/null "http://127.0.0.1:8000/health"; then
      printf 'ERRO: Brain API local (127.0.0.1:8000) não está ativa.\n' >&2
      return 2
    fi
    export KRYONIX_REMOTE_BRAIN_URL="http://127.0.0.1:8000"
  fi

  case "$mode" in
    --dry-run)
      # Nota: Atualmente o manifest inclui tudo (hosts, services, registry).
      # No futuro podemos adicionar um filtro ?type=registry se necessário.
      brain_remote_curl POST /graph/ingest/dry-run "{}"
      ;;
    --apply)
      local manifest_id="${brain_passthrough[0]:-}"
      if [[ -z "$manifest_id" ]]; then
        printf '%s\n' "Uso: kryonix graph ingest-registry --apply <manifest_id>" >&2
        return 2
      fi
      local payload
      payload="$(jq -n --arg manifest_id "$manifest_id" '{manifest_id:$manifest_id}')"
      brain_remote_curl POST /graph/ingest/apply "$payload"
      ;;
    *)
      printf '%s\n' "Uso: kryonix graph ingest-registry <--dry-run|--apply <manifest_id>> [--remote|--local]" >&2
      return 2
      ;;
  esac
}

kryonix_graph_query() {
  if [[ $# -eq 0 ]]; then
    kryonix_graph_query_usage
    return 2
  fi
  parse_brain_mode "$@"
  if ! brain_should_use_remote "$brain_mode"; then
    if ! curl -sS --max-time 2 -o /dev/null "http://127.0.0.1:8000/health"; then
      printf 'ERRO: Brain API local (127.0.0.1:8000) não está ativa.\n' >&2
      return 2
    fi
    export KRYONIX_REMOTE_BRAIN_URL="http://127.0.0.1:8000"
  fi
  local -a query_args
  query_args=("${brain_passthrough[@]}")
  if [[ "${query_args[0]:-}" == "--help" || "${query_args[0]:-}" == "-h" ]]; then
    kryonix_graph_query_usage
    return 0
  fi
  if [[ "${query_args[0]:-}" == "--cypher" ]]; then
    query_args=("${query_args[@]:1}")
  fi
  if [[ "${#query_args[@]}" -eq 0 ]]; then
    kryonix_graph_query_usage
    return 2
  fi
  local q="${query_args[*]}"
  kryonix_graph_validate_cypher_query "$q" || return $?
  local payload
  payload="$(jq -n --arg query "$q" --argjson timeout_sec 5 '{query:$query, timeout_sec:$timeout_sec}')"
  brain_remote_curl POST /graph/query "$payload"
}

kryonix_graph_doctor() {
  parse_brain_mode "$@"
  if brain_should_use_remote "$brain_mode"; then
    brain_remote_curl GET /graph/doctor
    return $?
  fi
  brain_local_curl GET /graph/doctor
}

kryonix_graph_top() {
  parse_brain_mode "$@"
  if brain_should_use_remote "$brain_mode"; then
    blue_line "WARN: graph top remoto ainda não possui endpoint público; rode no Glacier com kryonix graph top --local --limit 10."
    return 0
  fi

  graph_limit="$(graph_top_args "${brain_passthrough[@]}")"
  run_brain_cli top "$graph_limit"
}

kryonix_graph_server_only() {
  local action="$1"
  shift

  parse_brain_mode "$@"
  if brain_should_use_remote "$brain_mode"; then
    printf '%s\n' "kryonix graph $action é operação local do Glacier. Use --local no servidor." >&2
    return 2
  fi

  case "$action" in
    heal)
      run_brain_cli graph heal "${brain_passthrough[@]}"
      ;;
    repair)
      run_brain_cli repair-graph "${brain_passthrough[@]}"
      ;;
  esac
}

mcp_config_file() {
  local repo_root

  repo_root="$(kryonix_repo_root)" || return 1
  if [[ -f "$repo_root/.mcp.json" ]]; then
    printf '%s\n' "$repo_root/.mcp.json"
  elif [[ -f "$repo_root/.mcp.example.json" ]]; then
    printf '%s\n' "$repo_root/.mcp.example.json"
  else
    printf '%s\n' "kryonix: .mcp.json ou .mcp.example.json não encontrado em $repo_root." >&2
    return 1
  fi
}

print_mcp_config() {
  local config_file

  config_file="$(mcp_config_file)" || return 1
  if [[ "$(basename "$config_file")" == ".mcp.example.json" ]]; then
    blue_line "Usando .mcp.example.json; copie para .mcp.json para configurar a instância local."
  fi

  jq '
    def mask:
      if type == "object" then
        with_entries(
          if (.key | test("(?i)(token|key|secret|password)")) then
            .value = "<redacted>"
          else
            .value |= mask
          end
        )
      elif type == "array" then
        map(mask)
      else
        .
      end;
    .mcpServers | mask
  ' "$config_file"
}

kryonix_mcp_check() {
  local brain_runtime=0
  local passthrough=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --brain-runtime)
        brain_runtime=1
        ;;
      *)
        passthrough+=("$1")
        ;;
    esac
    shift
  done

  if (( brain_runtime )); then
    run_brain_cli mcp-check "${passthrough[@]}"
    return $?
  fi

  local repo_root
  repo_root="$(kryonix_repo_root)" || return 1

  if [[ -x "$repo_root/scripts/check-mcp.sh" ]]; then
    (
      cd "$repo_root"
      KRYONIX_MCP_SKIP_CLI=1 bash scripts/check-mcp.sh
    )
  else
    printf '%s\n' "kryonix: scripts/check-mcp.sh não encontrado ou não executável." >&2
    return 1
  fi
}

kryonix_mcp_doctor() {
  local repo_root
  repo_root="$(kryonix_repo_root)" || return 1

  print_mcp_config || true

  if [[ -x "$repo_root/scripts/check-mcp.sh" ]]; then
    (
      cd "$repo_root"
      KRYONIX_MCP_SKIP_CLI=1 bash scripts/check-mcp.sh
    )
  else
    printf '%s\n' "kryonix: scripts/check-mcp.sh não encontrado ou não executável." >&2
    return 1
  fi
}

graph_top_args() {
  local limit="10"
  local parsed=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --limit)
        if [[ $# -lt 2 ]]; then
          printf '%s\n' "kryonix graph top: --limit requer valor." >&2
          return 2
        fi
        limit="$2"
        shift
        ;;
      --limit=*)
        limit="${1#--limit=}"
        ;;
      *)
        parsed+=("$1")
        ;;
    esac
    shift
  done

  if [[ "${#parsed[@]}" -gt 0 && "${parsed[0]}" =~ ^[0-9]+$ ]]; then
    limit="${parsed[0]}"
  fi

  printf '%s\n' "$limit"
}

kryonix_brain_cag() {
  local sub_action="${1:-}"
  shift || true

  # Parse --local or --remote
  parse_brain_mode "$@"

  if brain_should_use_remote "$brain_mode"; then
    if [[ -z "$sub_action" ]]; then
      sub_action="status"
    fi

    case "$sub_action" in
      status)
        if [[ "${KRYONIX_JSON_MODE:-}" == "1" ]]; then
          brain_remote_curl GET /cag/status
          return $?
        else
          local response
          response="$(brain_remote_curl GET /cag/status)" || return $?
          local project_dir
          project_dir="$(brain_project_dir)" || return 1
          printf '%s' "$response" | uv run --project "$project_dir" python -c '
import sys, json
from rich.console import Console

try:
    data = json.load(sys.stdin)
except Exception:
    print("Erro ao decodificar a resposta remota.")
    sys.exit(1)

console = Console()
console.print("\n[bold green][/bold green][black on green]CAG REMOTE STATUS[/black on green][bold green][/bold green]")

status_val = data.get("status", "unknown")
is_active = status_val == "ok" or "version" in data or "total_files" in data

if is_active:
    num_files = data.get("total_files", data.get("num_files", 0))
    size_bytes = data.get("total_bytes", data.get("size_bytes", 0))
    created_at = data.get("built_at", data.get("created_at", "n/a"))
    freshness = data.get("freshness", "unknown")
    repo_commit = data.get("repo_commit", "n/a")

    fresh_label = f"[bold green]{freshness}[/bold green]" if freshness == "OK" else f"[bold yellow]{freshness}[/bold yellow]"
    if freshness == "unknown": fresh_label = "[dim]unknown[/dim]"

    console.print(f"  [cyan]Status:[/cyan]      [bold green]Ativo[/bold green]")
    console.print(f"  [cyan]Freshness:[/cyan]   {fresh_label}")
    console.print(f"  [cyan]Ficheiros:[/cyan]   {num_files}")
    console.print(f"  [cyan]Tamanho:[/cyan]     {size_bytes} bytes")
    console.print(f"  [cyan]Gerado em:[/cyan]   {created_at}")
    if repo_commit != "n/a":
        console.print(f"  [cyan]Commit:[/cyan]      [dim]{repo_commit[:8]}[/dim]")
else:
    msg = data.get("message", "Inativo / Não Encontrado")
    console.print(f"  [cyan]Status:[/cyan]      [bold red]{msg}[/bold red]")
    console.print("[dim]Use \"kryonix brain cag build\" no servidor para inicializar o CAG.[/dim]")
'
          return $?
        fi
        ;;
      ask|route)
        if [[ "${#brain_passthrough[@]}" -eq 0 ]]; then
          printf 'Uso: kryonix brain cag %s "pergunta"\n' "$sub_action" >&2
          return 2
        fi
        local query="${brain_passthrough[*]}"
        local payload
        payload="$(jq -n --arg query "$query" --argjson top_k 5 '{query:$query, top_k:$top_k}')"

        if [[ "${KRYONIX_JSON_MODE:-}" == "1" ]]; then
          brain_remote_curl POST "/cag/$sub_action" "$payload"
          return $?
        else
          local response
          response="$(brain_remote_curl POST "/cag/$sub_action" "$payload")" || return $?
          local project_dir
          project_dir="$(brain_project_dir)" || return 1
          printf '%s' "$response" | uv run --project "$project_dir" python -c '
import sys, json
from rich.console import Console
from rich.markdown import Markdown
from rich.panel import Panel
from rich.table import Table

try:
    data = json.load(sys.stdin)
except Exception:
    print("Erro ao decodificar a resposta remota.")
    sys.exit(1)

console = Console()
if "answer" in data:
    console.print("\n[bold green][/bold green][black on green]CAG REMOTE ASK[/black on green][bold green][/bold green]")
    answer_str = data.get("answer", "")
    console.print(Panel(Markdown(answer_str), border_style="green", title="[bold green]Kryonix CAG (Remote)[/bold green]", title_align="left"))

    sources = data.get("sources", [])
    if sources:
        console.print("\n[bold cyan]Ficheiros usados:[/bold cyan]")
        for i, src in enumerate(sources):
            console.print(f"  {i+1}. [bold white]{src}[/bold white]")
elif "matched_files" in data:
    console.print("\n[bold green][/bold green][black on green]CAG REMOTE ROUTING[/black on green][bold green][/bold green]")
    t = Table(show_header=True, header_style="bold green")
    t.add_column("Ficheiro", style="cyan")
    t.add_column("Score", justify="right", style="green")

    for f in data.get("matched_files", []):
        f_path = f.get("path", "n/a")
        f_score = f.get("score", 0.0)
        t.add_row(f_path, f"{f_score:.3f}")
    console.print(t)
else:
    print(json.dumps(data, indent=2))
'
          return $?
        fi
        ;;
      build|clear-cache)
        printf 'ERRO: O subcomando "cag %s" modifica arquivos no servidor e deve ser executado localmente no Glacier.\n' "$sub_action" >&2
        printf 'Execute: ssh glacier e rode: kryonix brain cag %s\n' "$sub_action" >&2
        return 1
        ;;
      *)
        printf 'Subcomando CAG desconhecido: %s\n' "$sub_action" >&2
        printf 'Subcomandos válidos: status, ask, route, build, clear-cache\n' >&2
        return 1
        ;;
    esac
  else
    run_brain_cli cag "$sub_action" "${brain_passthrough[@]}"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Brain API Key management
# Regras:
#   - Nunca imprimir o valor da chave.
#   - Arquivo: /etc/kryonix/brain.env  root:root 0600  fora do Git.
#   - Variável canônica: KRYONIX_BRAIN_API_KEY
#   - Geração: python3 secrets.token_hex(32)
#   - generate NÃO sobrescreve arquivo existente.
#   - rotate faz backup antes de sobrescrever.
# ─────────────────────────────────────────────────────────────────────────────

_brain_env_file="/etc/kryonix/brain.env"

brain_api_key_restart_service() {
  local unit
  for unit in kryonix-brain-api.service kryonix-brain.service; do
    if systemctl list-unit-files "$unit" --no-pager --no-legend 2>/dev/null | grep -q "^$unit"; then
      printf '  reiniciando %s...\n' "$unit"
      sudo systemctl restart "$unit"
      sleep 2
      return $?
    fi
  done

  printf '  serviço    : WARN (kryonix-brain-api/kryonix-brain não encontrado)\n'
  return 0
}

brain_api_key_status() {
  local env_file="$_brain_env_file"

  printf 'Brain API Key — status\n'

  if ! sudo test -f "$env_file" 2>/dev/null; then
    printf '  arquivo    : AUSENTE (%s)\n' "$env_file"
    printf '  AÇÃO       : rode "kryonix brain api-key generate" no Glacier.\n'
    return 1
  fi

  sudo stat -c '  arquivo    : %n' "$env_file"
  sudo stat -c '  dono/perm  : %U:%G %a' "$env_file"

  if sudo grep -q '^KRYONIX_BRAIN_API_KEY=' "$env_file" 2>/dev/null; then
    printf '  chave      : PRESENTE (valor não exibido)\n'
  else
    printf '  chave      : AUSENTE ou variável errada no arquivo\n'
    printf '  esperado   : KRYONIX_BRAIN_API_KEY=<hex>\n'
    return 1
  fi

  # Verificar API local (WARN se offline, não FAIL)
  if curl -fsS --connect-timeout 3 http://127.0.0.1:8000/health >/dev/null 2>&1; then
    printf '  api /health: OK\n'
  else
    printf '  api /health: WARN (offline ou não disponível neste host)\n'
  fi
}

brain_api_key_generate() {
  local env_file="$_brain_env_file"

  # Aviso no cliente (Inspiron): geração local é para o servidor
  if [[ "$(kryonix_brain_role)" == "client" ]]; then
    printf 'AVISO: Este host é detectado como cliente (não Glacier).\n' >&2
    printf 'A chave de API deve ser gerada e armazenada no Glacier.\n' >&2
    printf 'Se quiser forçar execução local (ex.: dev), continue sob sua responsabilidade.\n' >&2
  fi

  if sudo test -f "$env_file" 2>/dev/null; then
    printf 'brain.env já existe; não sobrescrevendo.\n'
    sudo stat -c '  dono/perm  : %U:%G %a  arquivo: %n' "$env_file"
    printf 'Para trocar a chave, use: kryonix brain api-key rotate\n'
    return 0
  fi

  local key
  key="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"

  if [[ -z "$key" ]]; then
    printf 'ERRO: chave gerada vazia.\n' >&2
    return 1
  fi

  local tmp
  tmp="$(mktemp)"
  printf 'KRYONIX_BRAIN_API_KEY=%s\n' "$key" > "$tmp"
  unset key

  sudo mkdir -p "$(dirname "$env_file")"
  sudo install -m 600 -o root -g root "$tmp" "$env_file"
  rm -f "$tmp"

  sudo stat -c '  dono/perm  : %U:%G %a  arquivo: %n' "$env_file"

  if systemctl list-unit-files 2>/dev/null | grep -q 'kryonix-brain-api.service'; then
    printf '  reiniciando kryonix-brain-api...\n'
    sudo systemctl restart kryonix-brain-api || true
  fi

  printf 'Brain API key criada com segurança.\n'
  printf 'Valor NÃO exibido. Use "kryonix brain api-key validate" para testar.\n'
}

brain_api_key_rotate() {
  local env_file="$_brain_env_file"
  local confirmed=0
  local dry_run=0
  local validate_after=1
  local arg

  for arg in "$@"; do
    case "$arg" in
      --yes|-y|--confirm)
        confirmed=1
        ;;
      --dry-run)
        dry_run=1
        ;;
      --validate)
        validate_after=1
        ;;
      --no-validate)
        validate_after=0
        ;;
      *)
        printf 'Opção desconhecida para rotate-api-key: %s\n' "$arg" >&2
        return 2
        ;;
    esac
  done

  if [[ "$dry_run" -eq 1 ]]; then
    printf 'Brain API key rotate — dry-run\n'
    printf '  arquivo    : %s\n' "$env_file"
    printf '  backup     : /root/kryonix-secret-backups/brain.env.<timestamp>.bak\n'
    printf '  restart    : kryonix-brain-api.service ou kryonix-brain.service\n'
    printf '  validate   : %s\n' "$([[ "$validate_after" -eq 1 ]] && printf 'yes' || printf 'no')"
    printf '  mutação    : nenhuma\n'
    printf 'Secret value printed: no\n'
    return 0
  fi

  if ! sudo test -f "$env_file" 2>/dev/null; then
    printf 'ERRO: %s não existe. Use "kryonix brain api-key generate" primeiro.\n' "$env_file" >&2
    return 1
  fi

  if [[ "$confirmed" -eq 0 ]]; then
    printf 'AVISO: rotate substitui a chave atual e reinicia o serviço.\n'
    printf 'Um backup será criado antes. Confirmar? [s/N] '
    local answer
    read -r answer
    case "$answer" in
      [sS][iI]|[sS]|[yY][eE][sS]|[yY])
        confirmed=1
        ;;
      *)
        printf 'Operação cancelada.\n'
        return 0
        ;;
    esac
  fi

  # Backup atômico com timestamp
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  local backup_dir="/root/kryonix-secret-backups"
  local backup_file="${backup_dir}/brain.env.${ts}.bak"

  sudo mkdir -p "$backup_dir"
  sudo chmod 700 "$backup_dir"
  sudo cp "$env_file" "$backup_file"
  sudo chown root:root "$backup_file"
  sudo chmod 600 "$backup_file"
  printf '  backup     : %s\n' "$backup_file"

  # Gerar nova chave
  local key
  key="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"

  if [[ -z "$key" ]]; then
    printf 'ERRO: nova chave gerada vazia. Backup preservado em %s\n' "$backup_file" >&2
    return 1
  fi

  local tmp
  tmp="$(mktemp)"
  printf 'KRYONIX_BRAIN_API_KEY=%s\n' "$key" > "$tmp"
  unset key

  sudo install -m 600 -o root -g root "$tmp" "$env_file"
  rm -f "$tmp"

  sudo stat -c '  dono/perm  : %U:%G %a  arquivo: %n' "$env_file"

  brain_api_key_restart_service || return $?

  printf 'KRYONIX_BRAIN_API_KEY rotated.\n'
  printf 'File: %s\n' "$env_file"
  printf 'Secret value printed: no\n'

  if [[ "$validate_after" -eq 1 ]]; then
    printf 'Validando nova chave...\n'
    brain_api_key_validate
  fi
}

brain_api_key_validate() {
  local env_file="$_brain_env_file"

  printf 'Brain API Key — validate\n'

  if ! sudo test -f "$env_file" 2>/dev/null; then
    printf '  FAIL: %s não existe.\n' "$env_file"
    return 1
  fi

  if ! sudo grep -q '^KRYONIX_BRAIN_API_KEY=' "$env_file" 2>/dev/null; then
    printf '  FAIL: KRYONIX_BRAIN_API_KEY ausente no arquivo.\n'
    return 1
  fi

  # Testar /health (público)
  if curl -fsS --connect-timeout 5 http://127.0.0.1:8000/health >/dev/null 2>&1; then
    printf '  /health    : OK\n'
  else
    printf '  /health    : WARN (API offline ou não disponível neste host)\n'
    printf '  Validação autenticada ignorada (API não responde).\n'
    return 0
  fi

  # Testar /stats com X-API-Key em subshell isolado (chave não vaza)
  local http_code
  local tmp_resp
  tmp_resp="$(mktemp)"

  http_code="$(
    K="$(sudo grep '^KRYONIX_BRAIN_API_KEY=' "$env_file" | cut -d'=' -f2- | tr -d '[:space:]')"
    curl -sS --connect-timeout 5 -w '%{http_code}' \
      -H "X-API-Key: $K" \
      -o "$tmp_resp" \
      http://127.0.0.1:8000/stats 2>/dev/null || true
    unset K
  )" || true

  if [[ "$http_code" == "200" ]]; then
    printf '  /stats     : OK (autenticado)\n'
  elif [[ "$http_code" == "403" || "$http_code" == "401" ]]; then
    printf '  /stats     : FAIL (chave inválida — HTTP %s)\n' "$http_code"
    rm -f "$tmp_resp"
    return 1
  else
    printf '  /stats     : WARN (HTTP %s — verificar serviço)\n' "${http_code:-erro}"
  fi

  rm -f "$tmp_resp"
  printf '  resultado  : OK (valor não exibido)\n'
}

kryonix_brain_rotate_api_key() {
  brain_strip_local_exec_flag "$@"

  local arg confirmed=0 dry_run=0
  for arg in "${brain_passthrough[@]}"; do
    case "$arg" in
      --help|-h)
        cat <<'EOF'
Uso: kryonix brain rotate-api-key [--host glacier] [--dry-run|--confirm] [--validate]

Rotaciona KRYONIX_BRAIN_API_KEY sem imprimir a chave:
  - sem --confirm, não altera nada e retorna erro
  - --dry-run mostra o plano e não altera nada
  - backup root-only em /root/kryonix-secret-backups/
  - escrita atômica em /etc/kryonix/brain.env
  - permissão root:root 0600
  - restart de kryonix-brain-api.service ou kryonix-brain.service
  - validação de /health e /stats
EOF
        return 0
        ;;
      --confirm)
        confirmed=1
        ;;
      --dry-run)
        dry_run=1
        ;;
    esac
  done

  if [[ "$confirmed" -ne 1 && "$dry_run" -ne 1 ]]; then
    printf 'ERRO: rotate-api-key exige --confirm para alterar a chave real.\n' >&2
    printf 'Use --dry-run para simular sem mutação.\n' >&2
    return 2
  fi

  if brain_should_run_remote_target; then
    brain_safe_remote_exec rotate-api-key "${brain_passthrough[@]}"
    return $?
  fi

  brain_api_key_rotate "${brain_passthrough[@]}"
}

kryonix_brain_api_key() {
  local sub="${1:-status}"
  shift || true

  case "$sub" in
    status)
      brain_api_key_status "$@"
      ;;
    generate)
      brain_api_key_generate "$@"
      ;;
    rotate)
      brain_api_key_rotate "$@"
      ;;
    validate)
      brain_api_key_validate "$@"
      ;;
    *)
      printf 'Uso: kryonix brain api-key <status|generate|rotate|validate>\n' >&2
      printf '\n' >&2
      printf '  status    verifica se /etc/kryonix/brain.env existe e tem a chave correta\n' >&2
      printf '  generate  cria a chave (não sobrescreve existente)\n' >&2
      printf '  rotate    substitui a chave (backup automático + restart do serviço)\n' >&2
      printf '  validate  testa /health e /stats com a chave (sem exibir o valor)\n' >&2
      return 1
      ;;
  esac
}

brain_safe_status_line() {
  printf '%-24s %s\n' "$1:" "$2"
}

brain_safe_scan_json() {
  local repo_root scanner
  repo_root="$(kryonix_repo_root)" || return 1
  scanner="$(brain_secret_scan_script)" || return 1
  python3 "$scanner" --repo "$repo_root" --json "$@"
}

brain_safe_scan_has_leak() {
  jq -e '
    any(.suspects[]?;
      ((.severity == "high" or .severity == "critical")
       and (.rule | test("possible_|private_key|env_file|pem_key|private_ssh"; "i")))
    )
  ' >/dev/null
}

brain_safe_print_scan_summary() {
  jq -r '
    "Preflight secrets: " + (.status | ascii_upcase),
    (if (.quarantine_dir // "") != "" then "Quarantine: " + .quarantine_dir else empty end),
    (if (.suspects | length) > 0 then
      "Suspects:" ,
      (.suspects[] | "- " + .path + " | tracked=" + (.tracked|tostring) + " | rule=" + .rule + " | severity=" + .severity + " | action=" + .recommended_action)
    else
      "Suspects: none"
    end),
    "No secret values were printed."
  '
}

brain_safe_require_clean_repo() {
  local repo_root changes
  repo_root="$(kryonix_repo_root)" || return 1
  changes="$(git -C "$repo_root" status --short)"
  if [[ -n "$changes" ]]; then
    printf 'Repo status: BLOCKED\n' >&2
    printf '%s\n' "$changes" >&2
    return 1
  fi
  brain_safe_status_line "Repo status" "PASS"
}

brain_safe_run_step() {
  local label="$1"
  shift
  printf '%s...\n' "$label"
  if "$@"; then
    brain_safe_status_line "$label" "PASS"
    return 0
  fi
  local status=$?
  brain_safe_status_line "$label" "FAIL ($status)"
  return "$status"
}

brain_safe_local_api_key() {
  local env_file="$_brain_env_file"
  if ! sudo test -f "$env_file" 2>/dev/null; then
    return 1
  fi
  sudo sed -n 's/^KRYONIX_BRAIN_API_KEY=//p' "$env_file" | tail -1 | tr -d '[:space:]'
}

brain_safe_api_request() {
  local method="$1"
  local path="$2"
  local output="$3"
  local data="${4:-}"
  local key
  local -a args

  args=(--connect-timeout 5 --max-time 120 -sS -w '%{http_code}' -o "$output" -X "$method")
  if [[ "$path" != "/health" ]]; then
    key="$(brain_safe_local_api_key)" || return 97
    if [[ -z "$key" ]]; then
      return 97
    fi
    args+=(-H "X-API-Key: $key")
  fi
  if [[ -n "$data" ]]; then
    args+=(-H "Content-Type: application/json" --data "$data")
  fi

  curl "${args[@]}" "http://127.0.0.1:8000$path"
}

brain_safe_search_smoke() {
  local label="$1"
  local intent="$2"
  local query="$3"
  local expect_normalized="${4:-0}"
  local tmp payload http_code grounding_label answer normalized mode returned_intent

  tmp="$(mktemp)"
  payload="$(jq -n --arg query "$query" --arg mode "hybrid" --arg intent "$intent" --arg lang "pt-BR" --argjson explain true '{query:$query, mode:$mode, intent:$intent, lang:$lang, explain:$explain}')"
  http_code="$(brain_safe_api_request POST /search "$tmp" "$payload" || true)"

  if [[ "$http_code" != "200" ]]; then
    rm -f "$tmp"
    brain_safe_status_line "$label" "FAIL (HTTP ${http_code:-erro})"
    return 1
  fi

  grounding_label="$(jq -r '.grounding.grounding_label // .grounding.confidence // .confidence // ""' "$tmp")"
  answer="$(jq -r '.answer // ""' "$tmp")"
  normalized="$(jq -r '.grounding.query_normalized // ""' "$tmp")"
  mode="$(jq -r '.grounding.mode // .mode // ""' "$tmp")"
  returned_intent="$(jq -r '.grounding.intent // .intent // ""' "$tmp")"

  if [[ "$grounding_label" == "Alta" && "$answer" == *"Não encontrei grounding suficiente"* ]]; then
    rm -f "$tmp"
    brain_safe_status_line "$label" "FAIL (grounding contraditório)"
    return 1
  fi
  if [[ "$mode" != "hybrid" || "$returned_intent" != "$intent" ]]; then
    rm -f "$tmp"
    brain_safe_status_line "$label" "FAIL (intent/mode ausente)"
    return 1
  fi
  if [[ "$expect_normalized" -eq 1 ]]; then
    if [[ "$normalized" != *"search"* || "$normalized" == *"seaarch"* || "$normalized" == *"diferena"* ]]; then
      rm -f "$tmp"
      brain_safe_status_line "$label" "FAIL (normalização ausente)"
      return 1
    fi
  fi

  rm -f "$tmp"
  brain_safe_status_line "$label" "PASS"
}

brain_safe_cag_smoke() {
  local label="$1"
  local method="$2"
  local path="$3"
  local data="${4:-}"
  local tmp http_code missing_status detail_text

  tmp="$(mktemp)"
  http_code="$(brain_safe_api_request "$method" "$path" "$tmp" "$data" || true)"
  missing_status="$(jq -r '.status // .detail.status // ""' "$tmp" 2>/dev/null || true)"
  detail_text="$(jq -r '.detail // ""' "$tmp" 2>/dev/null || true)"

  if [[ "$http_code" == "200" ]]; then
    rm -f "$tmp"
    brain_safe_status_line "$label" "PASS"
    return 0
  fi
  if [[ "$missing_status" == "missing_manifest" ]]; then
    rm -f "$tmp"
    brain_safe_status_line "$label" "WARN missing_manifest"
    return 0
  fi
  if [[ "$http_code" == "500" && "$detail_text" == *"No manifest found"* ]]; then
    rm -f "$tmp"
    brain_safe_status_line "$label" "FAIL (manifest virou HTTP 500)"
    return 1
  fi

  rm -f "$tmp"
  brain_safe_status_line "$label" "FAIL (HTTP ${http_code:-erro})"
  return 1
}

brain_safe_run_smokes() {
  local failures=0
  local tmp http_code payload

  # Aguarda o serviço subir (até 60s)
  printf 'Aguardando Brain API subir... '
  local i=0
  local max=12
  while [[ $i -lt $max ]]; do
    tmp="$(mktemp)"
    http_code="$(brain_safe_api_request GET /health "$tmp" || true)"
    rm -f "$tmp"
    if [[ "$http_code" == "200" ]]; then
       printf '\033[32mREADY\033[0m\n'
       break
    fi
    printf '.'
    sleep 5
    i=$((i + 1))
  done

  if [[ "$http_code" != "200" ]]; then
     printf '\033[31mTIMEOUT\033[0m\n'
     brain_safe_status_line "Brain health" "FAIL (HTTP ${http_code:-erro})"
     return 1
  fi

  brain_safe_status_line "Brain health" "PASS"

  tmp="$(mktemp)"
  http_code="$(brain_safe_api_request GET /stats "$tmp" || true)"
  rm -f "$tmp"
  if [[ "$http_code" == "200" ]]; then
    brain_safe_status_line "Brain stats" "PASS"
  else
    brain_safe_status_line "Brain stats" "FAIL (HTTP ${http_code:-erro})"
    failures=$((failures + 1))
  fi

  brain_safe_search_smoke "Ask/Search smoke" ask "qual diferença tem entre ask e search" 0 || failures=$((failures + 1))
  brain_safe_search_smoke "Search smoke" search "qual diferença tem entre ask e search" 0 || failures=$((failures + 1))
  brain_safe_search_smoke "Typo normalize smoke" ask "qual diferena tem entre o ask e seaarch" 1 || failures=$((failures + 1))

  brain_safe_cag_smoke "CAG status" GET /cag/status || failures=$((failures + 1))
  payload="$(jq -n --arg query "qual diferença tem entre ask e search" --argjson top_k 5 '{query:$query, top_k:$top_k}')"
  brain_safe_cag_smoke "CAG ask" POST /cag/ask "$payload" || failures=$((failures + 1))

  [[ "$failures" -eq 0 ]]
}

kryonix_brain_vram_audit() {
  local target
  target="$(map_runtime_host)"

  if [[ "$target" != "glacier" ]]; then
    printf 'VRAM audit é uma operação do servidor Glacier.\n' >&2
    return 0
  fi

  if ! command -v nvidia-smi >/dev/null 2>&1; then
    printf 'nvidia-smi não encontrado. GPU NVIDIA não disponível?\n' >&2
    return 1
  fi

  local total used free profile
  total=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1 | tr -d ' \r')
  used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1 | tr -d ' \r')
  free=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits | head -1 | tr -d ' \r')

  # Tenta ler o perfil atual se houver nix-instantiate ou se estiver no ambiente NixOS
  profile="unknown"
  if command -v nix-instantiate >/dev/null 2>&1; then
    profile=$(nix eval --raw "/etc/kryonix#nixosConfigurations.glacier.config.kryonix.services.brain.vram.profile" 2>/dev/null || echo "unknown")
  fi

  local status="OK"
  if [[ "$free" -lt 2048 ]]; then status="WARN"; fi
  if [[ "$free" -lt 512 ]]; then status="FAIL"; fi

  printf '\n[bold magenta][/bold magenta][black on magenta]GLACIER VRAM AUDIT[/black on magenta][bold magenta][/bold magenta]\n'
  printf 'GPU: [cyan]NVIDIA RTX 4060[/cyan]\n'
  printf 'VRAM: %s MiB usados / %s MiB total\n' "$used" "$total"
  printf 'Livre: [bold green]%s MiB[/bold green]\n' "$free"
  printf 'Perfil: [bold cyan]%s[/bold cyan]\n' "$profile"

  case "$status" in
    OK)   printf 'Status: [bold green]OK[/bold green]\n' ;;
    WARN) printf 'Status: [bold yellow]WARN[/bold yellow]\n' ;;
    FAIL) printf 'Status: [bold red]FAIL[/bold red]\n' ;;
  esac

  printf '\n[bold cyan]Top processos consumindo VRAM:[/bold cyan]\n'
  printf '%-8s %-10s %s\n' "PID" "VRAM" "Processo"
  nvidia-smi --query-compute-apps=pid,used_gpu_memory,process_name --format=csv,noheader,nounits | sort -k2 -rn | head -n 5 | while IFS=',' read -r pid vram proc; do
    printf '%-8s %-10s %s\n' "$pid" "${vram}MiB" "$proc"
  done

  printf '\n[bold yellow]Sessões Ativas:[/bold yellow]\n'
  loginctl list-sessions --no-legend
}

kryonix_brain_vram_check() {
  # Chama o script do NixOS que já implementa a lógica de perfil
  local check_script="/run/current-system/sw/bin/ollama-vram-check"
  if [[ -x "$check_script" ]]; then
    "$check_script"
  else
    # Fallback manual se o script não estiver no path
    /run/current-system/sw/bin/bash -c "source /etc/set-environment; /run/current-system/sw/bin/nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits"
  fi
}

kryonix_brain_vram_clear() {
  local confirm=0 dry_run=1
  for arg in "$@"; do
    case "$arg" in
      --confirm) confirm=1; dry_run=0 ;;
      --dry-run) dry_run=1; confirm=0 ;;
    esac
  done

  local target
  target="$(map_runtime_host)"
  if [[ "$target" != "glacier" ]]; then
    printf 'VRAM clear é uma operação do servidor Glacier.\n' >&2
    return 0
  fi

  printf 'Iniciando auditoria de candidatos a limpeza de VRAM...\n'

  local candidates=()
  # 1. Identifica sessões gráficas (gdm, hyprland, gnome)
  while read -r id user _seat type _state; do
    # Ignora sessões tty/ssh
    if [[ "$type" != "wayland" && "$type" != "x11" ]]; then continue; fi

    # Ignora a sessão atual
    if [[ "$id" == "$XDG_SESSION_ID" ]]; then continue; fi

    # Ignora sessões com jogos/apps críticos
    local session_procs
    session_procs=$(loginctl session-status "$id" --no-pager | grep -iE "steam|cs2|blender|obs|vnc|rdp" || true)
    if [[ -n "$session_procs" ]]; then
       printf 'Sessão %s ([cyan]%s[/cyan]) preservada (contém processos críticos: %s)\n' "$id" "$user" "$(echo "$session_procs" | awk '{print $1}' | tr '\n' ' ')"
       continue
    fi

    # Candidato detectado
    candidates+=("$id:$user:$type")
  done < <(loginctl list-sessions --no-legend)

  if [[ ${#candidates[@]} -eq 0 ]]; then
    printf 'Nenhum candidato seguro para encerramento automático encontrado.\n'
    return 0
  fi

  printf '\n[bold yellow]Candidatos detectados:[/bold yellow]\n'
  for c in "${candidates[@]}"; do
    IFS=':' read -r id user type <<< "$c"
    printf ' - Sessão [cyan]%s[/cyan] / usuário [bold]%s[/bold] / tipo %s / motivo: sessão gráfica inativa ou órfã\n' "$id" "$user" "$type"
  done

  if [[ "$confirm" -eq 1 ]]; then
    for c in "${candidates[@]}"; do
      IFS=':' read -r id user type <<< "$c"
      printf 'Encerrando sessão %s via loginctl terminate-session...\n' "$id"
      sudo loginctl terminate-session "$id"
    done
    printf 'Limpeza concluída.\n'
  else
    printf '\n[bold cyan]DICA:[/bold cyan] Para encerrar esses candidatos, use: [bold]kryonix brain vram-clear --confirm[/bold]\n'
  fi
}

kryonix_brain_vram_profile() {
  local profile="${1:-}"
  local confirm=0 dry_run=1
  shift || true
  for arg in "$@"; do
    case "$arg" in
      --confirm) confirm=1; dry_run=0 ;;
      --dry-run) dry_run=1; confirm=0 ;;
    esac
  done

  if [[ -z "$profile" ]]; then
    printf 'Uso: kryonix brain vram-profile <ai|balanced|gaming> [--dry-run|--confirm]\n' >&2
    return 2
  fi

  printf 'Operação de Perfil Runtime: [bold cyan]%s[/bold cyan]\n' "$profile"

  if [[ "$dry_run" -eq 1 ]]; then
    printf '[yellow]MODO DRY-RUN[/yellow] (não altera serviços)\n'
    case "$profile" in
      ai)
        printf ' - Validaria VRAM contra threshold AI (4GiB)\n'
        printf ' - Sugeriria vram-clear se necessário\n'
        printf ' - Reiniciaria ollama.service e kryonix-brain-api.service\n'
        ;;
      gaming)
        printf ' - Pararia ollama.service\n'
        printf ' - Manteria Brain API ativa (degradada)\n'
        ;;
      balanced)
        printf ' - Reiniciaria serviços com perfil padrão\n'
        ;;
    esac
    printf '\nUse [bold]--confirm[/bold] para aplicar no runtime.\n'
    return 0
  fi

  # Modo --confirm
  case "$profile" in
    ai)
      kryonix_brain_vram_audit
      if ! kryonix_brain_vram_check; then
        printf '[bold red]ERRO:[/bold red] VRAM insuficiente para modo AI. Tente [bold]kryonix brain vram-clear --confirm[/bold] primeiro.\n' >&2
        return 1
      fi
      printf 'Iniciando serviços modo AI...\n'
      sudo systemctl restart ollama kryonix-brain-api
      kryonix_brain_health || true
      ;;
    gaming)
      printf 'Entrando em modo GAMING (liberando GPU)...\n'
      sudo systemctl stop ollama
      printf 'Ollama parado. Brain API permanece ativa (search degradado).\n'
      ;;
    balanced)
      printf 'Retornando ao perfil BALANCED...\n'
      sudo systemctl restart ollama kryonix-brain-api
      ;;
  esac
}

kryonix_brain_deploy_safe() {
  brain_strip_local_exec_flag "$@"

  local quarantine=0 rotate_if_leaked=0 rotate_key=0 run_test=0 run_switch=0
  local arg
  for arg in "${brain_passthrough[@]}"; do
    case "$arg" in
      --quarantine-untracked)
        quarantine=1
        ;;
      --rotate-if-leaked)
        rotate_if_leaked=1
        ;;
      --rotate-key)
        rotate_key=1
        ;;
      --test)
        run_test=1
        ;;
      --switch)
        run_switch=1
        ;;
      --help|-h)
        cat <<'EOF'
Uso: kryonix brain deploy-safe --host glacier [flags]

Flags:
  --quarantine-untracked  move somente suspeitos não rastreados para quarentena privada
  --rotate-if-leaked      rotaciona KRYONIX_BRAIN_API_KEY se o preflight detectar vazamento
  --rotate-key            força rotação da KRYONIX_BRAIN_API_KEY
  --test                  executa kryonix test --host glacier
  --switch                executa kryonix switch --host glacier após todos os gates

Sem --switch, o deploy permanente é sempre SKIPPED.
EOF
        return 0
        ;;
      *)
        printf 'Opção desconhecida para deploy-safe: %s\n' "$arg" >&2
        return 2
        ;;
    esac
  done

  if [[ "$run_switch" -eq 1 && "$run_test" -ne 1 ]]; then
    printf 'ERRO: --switch requer --test no deploy-safe.\n' >&2
    return 2
  fi

  if brain_should_run_remote_target; then
    brain_safe_require_clean_repo || return $?
    brain_safe_remote_exec deploy-safe "${brain_passthrough[@]}"
    return $?
  fi

  local repo_root scan_json scan_status leak_detected=0 self target
  repo_root="$(kryonix_repo_root)" || return 1
  target="$(brain_safe_target_host)"
  self="${KRYONIX_BIN:-$0}"

  printf 'Kryonix Brain Safe Deploy\n\n'

  scan_status=0
  scan_json="$(brain_safe_scan_json)" || scan_status=$?
  scan_status="${scan_status:-0}"
  if printf '%s\n' "$scan_json" | brain_safe_scan_has_leak; then
    leak_detected=1
  fi

  if [[ "$scan_status" -ne 0 ]]; then
    if [[ "$quarantine" -eq 1 ]]; then
      printf '%s\n' "$scan_json" | brain_safe_print_scan_summary
      printf 'Quarentenando suspeitos não rastreados...\n'
      scan_status=0
      scan_json="$(brain_safe_scan_json --quarantine-untracked)" || scan_status=$?
    else
      printf '%s\n' "$scan_json" | brain_safe_print_scan_summary
      printf 'Status: BLOCKED\n' >&2
      return 1
    fi
  fi

  scan_status=0
  scan_json="$(brain_safe_scan_json)" || scan_status=$?
  scan_status="${scan_status:-0}"
  printf '%s\n' "$scan_json" | brain_safe_print_scan_summary
  if [[ "$scan_status" -ne 0 ]]; then
    printf 'Status: BLOCKED\n' >&2
    return 1
  fi

  if [[ "$rotate_key" -eq 1 || ( "$rotate_if_leaked" -eq 1 && "$leak_detected" -eq 1 ) ]]; then
    brain_safe_run_step "API key rotation" "$self" brain rotate-api-key --host "$target" --local-exec --confirm --validate || return $?
  else
    brain_safe_status_line "API key rotation" "SKIPPED"
  fi

  brain_safe_require_clean_repo || return $?

  brain_safe_run_step "Git fetch" git -C "$repo_root" fetch origin || return $?
  brain_safe_run_step "Git pull" git -C "$repo_root" pull --ff-only origin main || return $?
  brain_safe_run_step "Submodules" git -C "$repo_root" submodule update --init --recursive || return $?
  git -C "$repo_root" submodule status --recursive

  brain_safe_run_step "Git status" "$self" git-status || return $?
  brain_safe_run_step "Build check" "$self" check --host "$target" || return $?
  brain_safe_run_step "Rebuild" "$self" rebuild --host "$target" || return $?

  if [[ "$run_test" -eq 1 ]]; then
    brain_safe_run_step "Test activation" "$self" test --host "$target" || return $?
  else
    brain_safe_status_line "Test activation" "SKIPPED"
  fi

  if brain_safe_run_smokes; then
    brain_safe_status_line "Brain/CAG smokes" "PASS"
  else
    brain_safe_status_line "Brain/CAG smokes" "FAIL"
    return 1
  fi

  if [[ "$run_switch" -eq 1 ]]; then
    brain_safe_run_step "Switch" "$self" switch --host "$target" || return $?
    printf '\nStatus: DEPLOYED\n'
  else
    brain_safe_status_line "Switch" "SKIPPED"
    printf '\nStatus: READY_FOR_SWITCH\n'
  fi
}

kryonix_brain_remote_status() {
  local conf="$HOME/.config/kryonix/brain-remote.env"
  if [[ -f "$conf" ]]; then
    printf 'Configuração remota encontrada em %s\n' "$conf"
    # shellcheck disable=SC1090,SC1091
    source "$conf"
    printf 'URL configurada: %s\n' "${KRYONIX_REMOTE_BRAIN_URL:-<não definida>}"
    if [[ -n "${KRYONIX_BRAIN_API_KEY:-}" ]]; then
      printf 'Chave API: *** (configurada)\n'
    else
      printf 'Chave API: <não configurada>\n'
    fi
  else
    printf 'Nenhuma configuração remota encontrada.\n'
    printf 'Rode: kryonix brain remote configure --url <URL> --key-stdin\n'
  fi
}

kryonix_brain_remote_configure() {
  local url=""
  local key=""
  local use_stdin=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --url)
        url="$2"
        shift 2
        ;;
      --key-stdin)
        use_stdin=true
        shift
        ;;
      *)
        printf 'Opção desconhecida: %s\n' "$1" >&2
        return 2
        ;;
    esac
  done

  if [[ -z "$url" ]]; then
    printf 'ERRO: --url é obrigatório.\n' >&2
    return 2
  fi

  if $use_stdin; then
    IFS= read -r key
  else
    printf 'ERRO: --key-stdin é obrigatório para evitar vazamento da chave no histórico.\n' >&2
    return 2
  fi

  if [[ -z "$key" ]]; then
    printf 'ERRO: chave vazia.\n' >&2
    return 2
  fi

  local conf_dir="$HOME/.config/kryonix"
  local conf_file="$conf_dir/brain-remote.env"

  mkdir -p "$conf_dir"
  touch "$conf_file"
  chmod 0600 "$conf_file"

  cat > "$conf_file" <<EOF
KRYONIX_REMOTE_BRAIN_URL=$url
KRYONIX_BRAIN_API_KEY=$key
EOF

  printf 'Configuração salva em %s\n' "$conf_file"
}

kryonix_brain_remote_validate() {
  local conf="$HOME/.config/kryonix/brain-remote.env"
  if [[ ! -f "$conf" ]]; then
    printf 'ERRO: Nenhuma configuração encontrada. Rode kryonix brain remote configure.\n' >&2
    return 2
  fi
  # shellcheck disable=SC1090,SC1091
  source "$conf"

  printf 'Testando /health... '
  if curl -fsS --max-time 5 "${KRYONIX_REMOTE_BRAIN_URL}/health" >/dev/null 2>&1; then
    printf 'OK\n'
  else
    printf 'FALHA\n'
    return 1
  fi

  printf 'Testando /stats (autenticação)... '
  local st
  st="$(curl -sS --max-time 5 -w "%{http_code}" -o /dev/null -H "X-API-Key: $KRYONIX_BRAIN_API_KEY" "${KRYONIX_REMOTE_BRAIN_URL}/stats")"
  if [[ "$st" == "200" ]]; then
    printf 'OK\n'
  else
    printf 'FALHA (HTTP %s)\n' "$st"
    return 1
  fi
}

kryonix_brain_provider_status() {
  parse_brain_mode "$@"

  if brain_should_use_remote "$brain_mode"; then
    printf '🧠 [bold magenta]Kryonix Brain Provider Status (Remote)[/bold magenta]\n'
    local url
    url="$(brain_api_url)"
    printf 'URL da API: %s\n' "$url"

    # Tentativa de pegar info via /health ou /stats
    brain_remote_curl GET /health
    return $?
  fi

  printf '🧠 [bold magenta]Kryonix Brain Provider Status (Local)[/bold magenta]\n'
  export_brain_env

  local provider="${KRYONIX_LLM_PROVIDER:-ollama}"
  local ollama_url="${KRYONIX_OLLAMA_URL:-http://127.0.0.1:11434}"
  local llama_url="${KRYONIX_LLAMA_CPP_URL:-http://127.0.0.1:11435}"

  printf 'Provider configurado: [bold cyan]%s[/bold cyan]\n' "$provider"

  # Check Ollama
  printf 'Ollama:    '
  if curl -fsS --max-time 2 "$ollama_url/api/tags" >/dev/null 2>&1; then
    printf '[bold green]READY[/bold green]  %s\n' "$ollama_url"
  else
    printf '[bold red]OFFLINE[/bold red] %s\n' "$ollama_url"
  fi

  # Check llama.cpp
  printf 'llama.cpp: '
  if curl -fsS --max-time 2 "$llama_url/health" >/dev/null 2>&1; then
    printf '[bold green]READY[/bold green]  %s\n' "$llama_url"
  else
    printf '[bold red]OFFLINE[/bold red] %s\n' "$llama_url"
  fi

  printf 'Embedding: [dim]Ollama / nomic-embed-text[/dim]\n'

  case "$provider" in
    auto)
      printf '\nDecisão: [bold green]llama.cpp[/bold green] será usado para geração; [bold yellow]Ollama[/bold yellow] como fallback.\n'
      ;;
    llama_cpp)
      printf '\nDecisão: Apenas [bold green]llama.cpp[/bold green] será usado para geração.\n'
      ;;
    *)
      printf '\nDecisão: Apenas [bold green]Ollama[/bold green] será usado para geração.\n'
      ;;
  esac
}

kryonix_brain_provider_test() {
  local target_provider="auto"
  local -a passthrough=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --provider)
        target_provider="$2"
        shift 2
        ;;
      *)
        passthrough+=("$1")
        shift
        ;;
    esac
  done

  parse_brain_mode "${passthrough[@]}"
  export_brain_env

  local query="Responda apenas com a palavra TESTE."
  local payload
  payload="$(jq -n --arg query "$query" --arg mode "naive" --arg provider "$target_provider" '{query:$query, mode:$mode, test_provider:$provider}')"

  local api_url="http://127.0.0.1:8000"
  if [[ "$(kryonix_brain_role)" == "client" ]]; then
    api_url="${KRYONIX_BRAIN_URL:-http://10.0.0.2:8000}"
  fi

  printf 'Testando provider [bold cyan]%s[/bold cyan] via API (%s)...\n' "$target_provider" "$api_url"

  local tmp_json
  tmp_json=$(mktemp)

  # Try to use the API
  if curl -fsS -X POST "$api_url/search" \
     -H "Content-Type: application/json" \
     -H "X-API-Key: ${KRYONIX_BRAIN_API_KEY:-}" \
     -d "$payload" > "$tmp_json" 2>/dev/null; then

    local tps duration clean_json
    clean_json=$(grep '^{.*}$' "$tmp_json" | tail -n 1)
    if [[ -z "$clean_json" ]]; then clean_json=$(cat "$tmp_json"); fi

    tps=$(echo "$clean_json" | jq -r '.metrics.tps // 0')
    duration=$(echo "$clean_json" | jq -r '.metrics.total_duration_ms // 0')

    if (( $(echo "$tps > 0" | bc -l) )); then
      LC_NUMERIC=C printf 'Resultado: [bold green]PASS[/bold green] | TPS: [bold yellow]%.2f[/bold yellow] | Latência: [bold blue]%.0f ms[/bold blue]\n' "$tps" "$duration"
    else
      LC_NUMERIC=C printf 'Resultado: [bold green]PASS[/bold green] | Latência: [bold blue]%.0f ms[/bold blue]\n' "$duration"
    fi
    rm -f "$tmp_json"
    return 0
  fi

  # Fallback to local CLI if API fails and we are on server
  if [[ "$(kryonix_brain_role)" == "server" ]]; then
    printf '[yellow]API indisponível. Tentando CLI local...[/yellow]\n'
    local project_dir
    project_dir="$(brain_project_dir)" || return 1
    export_brain_env
    # Note: this might still fail with libstdc++ if not patched, but it is our last resort
    run_command uv run --project "$project_dir" python -m kryonix_brain_lightrag.cli chunks "$query" --test-provider "$target_provider" --json > "$tmp_json"

    local tps duration clean_json
    clean_json=$(grep '^{.*}$' "$tmp_json" | tail -n 1)
    if [[ -z "$clean_json" ]]; then clean_json=$(cat "$tmp_json"); fi

    tps=$(echo "$clean_json" | jq -r '.metrics.tps // 0')
    duration=$(echo "$clean_json" | jq -r '.metrics.total_duration_ms // 0')

    if (( $(echo "$tps > 0" | bc -l) )); then
      LC_NUMERIC=C printf 'Resultado: [bold green]PASS[/bold green] | TPS: [bold yellow]%.2f[/bold yellow] | Latência: [bold blue]%.0f ms[/bold blue]\n' "$tps" "$duration"
    else
      LC_NUMERIC=C printf 'Resultado: [bold green]PASS[/bold green] | Latência: [bold blue]%.0f ms[/bold blue]\n' "$duration"
    fi
  else
    printf '[bold red]ERRO:[/bold red] API indisponível em %s\n' "$api_url"
  fi
  rm -f "$tmp_json"
}

kryonix_brain_provider() {
  local sub="${1:-status}"
  shift || true
  case "$sub" in
    status) kryonix_brain_provider_status "$@" ;;
    test)   kryonix_brain_provider_test "$@" ;;
    *)
      printf 'Uso: kryonix brain provider <status|test [--provider <ollama|llama_cpp|auto>]>\n' >&2
      return 2
      ;;
  esac
}

kryonix_brain_remote() {
  local sub="${1:-help}"
  shift || true

  case "$sub" in
    status)
      kryonix_brain_remote_status "$@"
      ;;
    configure)
      kryonix_brain_remote_configure "$@"
      ;;
    validate)
      kryonix_brain_remote_validate "$@"
      ;;
    *)
      printf 'Uso: kryonix brain remote <status|configure|validate>\n' >&2
      return 2
      ;;
  esac
}

kryonix_brain_llama_cpp_status() {
  printf '[bold cyan]LLAMA.CPP BACKEND STATUS[/bold cyan]\n'
  local port=11435
  if ss -ltnp | grep -q ":$port "; then
    printf 'Serviço: [bold green]ONLINE[/bold green] (Porta %s)\n' "$port"
    local pid
    pid=$(ss -ltnp | grep ":$port " | awk -F'pid=' '{print $2}' | cut -d',' -f1)
    printf 'PID: %s\n' "$pid"
  else
    printf 'Serviço: [bold red]OFFLINE[/bold red]\n'
  fi

  if systemctl is-active --quiet kryonix-llama-cpp 2>/dev/null; then
    printf 'Systemd: [bold green]active[/bold green]\n'
  else
    printf 'Systemd: [bold yellow]inactive/not found[/bold yellow]\n'
  fi
}

kryonix_brain_llama_cpp_smoke() {
  local port=11435
  printf 'Testando llama.cpp em 127.0.0.1:%s...\n' "$port"
  if ! curl -fsS "http://127.0.0.1:$port/health" >/dev/null 2>&1; then
    printf '[bold red]ERRO:[/bold red] Backend não responde em 127.0.0.1:%s\n' "$port" >&2
    return 1
  fi

  printf 'Enviando chat completion de teste...\n'
  local res
  res=$(curl -s -X POST "http://127.0.0.1:$port/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d '{
      "messages": [{"role": "user", "content": "Hello. Respond with exactly one word: OK."}],
      "max_tokens": 10
    }' | grep -oP '"content":\s*"\K[^"]+')

  if [[ "$res" == "OK" || "$res" == "OK." ]]; then
    printf 'Smoke Test: [bold green]PASS[/bold green] (Resposta: %s)\n' "$res"
  else
    printf 'Smoke Test: [bold yellow]WARN[/bold yellow] (Resposta inesperada: %s)\n' "$res"
  fi
}

kryonix_brain_llama_cpp_bench() {
  local port=11435
  local model="qwen3-8b"
  printf 'Iniciando benchmark llama.cpp (127.0.0.1:%s)...\n' "$port"

  # Usando o endpoint /props para pegar info do modelo se disponível
  local model_info
  model_info=$(curl -s "http://127.0.0.1:$port/props" | grep -oP '"model_path":\s*"\K[^"]+' || echo "unknown")
  printf 'Modelo carregado: [cyan]%s[/cyan]\n' "$model_info"

  printf 'Executando teste de geração (50 tokens)...\n'
  local start_time end_time elapsed tokens
  start_time=$(date +%s%N)

  # Request real para medir tokens/s
  local output
  output=$(curl -s -X POST "http://127.0.0.1:$port/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d '{
      "messages": [{"role": "user", "content": "Escreva um parágrafo sobre a história da IA."}],
      "max_tokens": 50,
      "stream": false
    }')

  end_time=$(date +%s%N)
  elapsed=$(( (end_time - start_time) / 1000000 )) # ms

  tokens=$(echo "$output" | grep -oP '"completion_tokens":\s*\K\d+' || echo "0")

  if [[ "$tokens" -gt 0 ]]; then
    local tps
    tps=$(LC_NUMERIC=C awk "BEGIN {print $tokens / ($elapsed / 1000)}")
    printf 'Tokens gerados: %s\n' "$tokens"
    printf 'Tempo total: %sms\n' "$elapsed"
    LC_NUMERIC=C printf 'Performance: [bold green]%.2f tokens/s[/bold green]\n' "$tps"
  else
    printf '[bold red]ERRO:[/bold red] Falha ao capturar métricas do benchmark.\n' >&2
    return 1
  fi
}

kryonix_brain_llama_cpp() {
  local sub="${1:-help}"
  shift || true

  case "$sub" in
    status)
      kryonix_brain_llama_cpp_status "$@"
      ;;
    smoke)
      kryonix_brain_llama_cpp_smoke "$@"
      ;;
    bench)
      kryonix_brain_llama_cpp_bench "$@"
      ;;
    *)
      printf 'Uso: kryonix brain llama-cpp <status|smoke|bench>\n' >&2
      return 2
      ;;
  esac
}

# =============================================================================
# Brain Stack Service Control
#
# Controla os serviços do stack Brain via systemctl (nunca enable/disable).
# Ordem de start: ollama → neo4j → kryonix-brain-api
# Ordem de stop:  inversa
# kryonix-lightrag é oneshot gerenciado automaticamente pelo systemd como
# dependência de kryonix-brain-api — não precisa de controle manual.
# =============================================================================

_BRAIN_SVC_ORDER=(ollama neo4j kryonix-brain-api)

_brain_need_glacier_ssh() {
  [[ "$(hostname)" != "RVE-GLACIER" ]] && [[ "$(map_runtime_host)" == "glacier" ]]
}

_brain_glacier_ssh() {
  ssh -p 2224 rocha@10.0.0.2 "kryonix brain $*"
}

_brain_svc_start() {
  local svc="$1"

  if ! systemctl cat "$svc" --no-pager &>/dev/null; then
    printf '  %-26s  não configurado (pulando)\n' "$svc"
    return 0
  fi

  if systemctl is-active --quiet "$svc" 2>/dev/null; then
    printf '  %-26s  já rodando\n' "$svc"
    return 0
  fi

  printf '  %-26s  iniciando...' "$svc"
  if sudo systemctl start "$svc" 2>/dev/null; then
    printf ' OK\n'
    if [[ "$svc" == "ollama" ]]; then
      if command -v nvidia-smi &>/dev/null; then
        local free; free=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader 2>/dev/null || printf '?')
        printf '    VRAM livre: %s\n' "$free"
      elif command -v rocm-smi &>/dev/null; then
        rocm-smi --showmeminfo vram 2>/dev/null || true
      fi
    fi
  else
    printf ' FALHOU\n'
    printf '  Detalhes: journalctl -u %s --no-pager -n 20\n' "$svc" >&2
    return 1
  fi
}

_brain_svc_stop() {
  local svc="$1"

  if ! systemctl cat "$svc" --no-pager &>/dev/null; then
    return 0
  fi

  if ! systemctl is-active --quiet "$svc" 2>/dev/null; then
    printf '  %-26s  já parado\n' "$svc"
    return 0
  fi

  printf '  %-26s  parando...' "$svc"
  if sudo systemctl stop "$svc" 2>/dev/null; then
    printf ' OK\n'
  else
    printf ' FALHOU (não-crítico)\n'
  fi
}

kryonix_brain_stack_status() {
  _brain_need_glacier_ssh && { _brain_glacier_ssh "status" "$@"; return $?; }

  local -a services=("${_BRAIN_SVC_ORDER[@]}")
  printf '%-26s  %-10s  %s\n' "SERVIÇO" "ESTADO" "DESDE"
  printf '%-26s  %-10s  %s\n' "──────────────────────────" "──────────" "──────────────────────"

  local svc
  for svc in "${services[@]}"; do
    if ! systemctl cat "$svc" --no-pager &>/dev/null; then
      printf '%-26s  %-10s  %s\n' "$svc" "n/a" "(não configurado)"
      continue
    fi

    local state since
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
      state="running"
      since=$(systemctl show "$svc" --property=ActiveEnterTimestamp --value 2>/dev/null | sed 's/ [A-Z]*$//' || printf '')
    elif systemctl is-failed --quiet "$svc" 2>/dev/null; then
      state="FAILED"
      since=$(systemctl show "$svc" --property=InactiveEnterTimestamp --value 2>/dev/null | sed 's/ [A-Z]*$//' || printf '')
    else
      state="dead"
      since="—"
    fi
    printf '%-26s  %-10s  %s\n' "$svc" "$state" "$since"
  done

  if systemctl is-active --quiet ollama 2>/dev/null; then
    printf '\n── GPU VRAM ──\n'
    if command -v nvidia-smi &>/dev/null; then
      nvidia-smi --query-gpu=name,memory.used,memory.free,memory.total --format=csv,noheader
    elif command -v rocm-smi &>/dev/null; then
      rocm-smi --showmeminfo vram 2>/dev/null || printf 'rocm-smi: formato não suportado\n'
    fi
  fi
}

kryonix_brain_stack_start() {
  _brain_need_glacier_ssh && { _brain_glacier_ssh "start" "$@"; return $?; }

  local target="${1:-}"

  if [[ -n "$target" ]]; then
    _brain_svc_start "$target"
    return $?
  fi

  local svc
  for svc in "${_BRAIN_SVC_ORDER[@]}"; do
    if ! _brain_svc_start "$svc"; then
      printf 'ERRO: Falha ao iniciar %s — abortando sequência.\n' "$svc" >&2
      return 1
    fi
  done
  printf '\nStack Brain iniciada. Verifique: kryonix brain status\n'
}

kryonix_brain_stack_stop() {
  _brain_need_glacier_ssh && { _brain_glacier_ssh "stop" "$@"; return $?; }

  local target="${1:-}"

  if [[ -n "$target" ]]; then
    _brain_svc_stop "$target"
    return $?
  fi

  # Stop in reverse order
  local -a rev=()
  local svc
  for svc in "${_BRAIN_SVC_ORDER[@]}"; do
    rev=("$svc" "${rev[@]}")
  done

  for svc in "${rev[@]}"; do
    _brain_svc_stop "$svc"
  done

  if command -v nvidia-smi &>/dev/null; then
    printf '\nVRAM livre: '
    nvidia-smi --query-gpu=memory.free --format=csv,noheader 2>/dev/null || printf '?\n'
  fi
  printf 'Stack Brain parada.\n'
}

kryonix_brain_stack_restart() {
  _brain_need_glacier_ssh && { _brain_glacier_ssh "restart" "$@"; return $?; }

  local target="${1:-}"

  if [[ -n "$target" ]]; then
    printf 'Reiniciando %s...\n' "$target"
    _brain_svc_stop "$target"
    _brain_svc_start "$target"
    return $?
  fi

  printf 'Reiniciando stack Brain...\n'
  kryonix_brain_stack_stop
  printf '\n'
  kryonix_brain_stack_start
}
