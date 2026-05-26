#!/usr/bin/env bash
# =============================================================================
# kryonix-monitors — Controle de multi-monitor para Hyprland
# Autor: Gabriel Rocha (rag)
#
# Subcomandos:
#   (sem args)                     Lista monitores ativos
#   mode extend                    Estende lado a lado
#   mode duplicate                 Duplica/espelha todos no monitor interno
#   mode internal                  Só tela interna (desliga externos)
#   mode external                  Só monitor externo (desliga interno)
#   mode toggle                    Cicla: extend → duplicate → internal → external → extend
#   primary <output>               Define monitor primário (move workspaces default)
#   resolution <output> <WxH[@Hz]> Muda resolução em runtime
#   position <output> <XxY>        Reposiciona monitor
#   scale <output> <fator>         Muda escala (1.0, 1.25, 1.5, 2.0)
#   swap                           Troca posição entre 2 monitores
#   menu                           Abre menu rofi interativo
#   restore                        Restaura último modo salvo ao iniciar sessão
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Constantes
# ---------------------------------------------------------------------------
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/kryonix"
STATE_FILE="$STATE_DIR/monitor-mode"
MODES=(extend duplicate internal external)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
notify() {
  notify-send -a "🖥️ Monitor" -t 3000 "$1" "${2:-}" 2>/dev/null || true
}

get_monitors() {
  hyprctl monitors -j 2>/dev/null
}

# Retorna lista de outputs ativos (nome)
active_outputs() {
  get_monitors | jq -r '.[].name'
}

# Retorna o output interno (eDP-*)
internal_output() {
  get_monitors | jq -r '[.[] | select(.name | startswith("eDP"))] | first | .name // empty'
}

# Retorna outputs externos (não eDP-*)
external_outputs() {
  get_monitors | jq -r '[.[] | select(.name | startswith("eDP") | not)] | .[].name'
}

# Quantidade de monitores conectados
monitor_count() {
  get_monitors | jq 'length'
}

# Verifica se é notebook (tem eDP)
is_notebook() {
  local edp
  edp=$(internal_output)
  [[ -n "$edp" ]]
}

# Salva modo atual no estado
save_mode() {
  mkdir -p "$STATE_DIR"
  printf '%s\n' "$1" > "$STATE_FILE"
}

# Lê modo salvo
read_mode() {
  cat "$STATE_FILE" 2>/dev/null || echo "extend"
}

# Modo atual inferido pelo estado do hyprctl
detect_current_mode() {
  local saved
  saved=$(read_mode)
  echo "$saved"
}

# Próximo modo no ciclo
next_mode() {
  local current="$1"
  local count
  count=$(monitor_count)

  # Com 1 monitor, não faz sentido ciclar entre modos multi-monitor
  if [[ "$count" -le 1 ]]; then
    echo "extend"
    return
  fi

  case "$current" in
    extend)    echo "duplicate" ;;
    duplicate) echo "internal" ;;
    internal)  echo "external" ;;
    external)  echo "extend" ;;
    *)         echo "extend" ;;
  esac
}

# Posiciona monitores lado a lado automaticamente
arrange_side_by_side() {
  local offset=0
  # Interno sempre primeiro (posição 0)
  local internal
  internal=$(internal_output)

  if [[ -n "$internal" ]]; then
    hyprctl keyword monitor "${internal},preferred,${offset}x0,1" 2>/dev/null
    local w
    w=$(get_monitors | jq -r --arg n "$internal" '.[] | select(.name==$n) | .width // 1920')
    offset=$((offset + w))
  fi

  # Externos na sequência
  while IFS= read -r out; do
    [[ -z "$out" ]] && continue
    hyprctl keyword monitor "${out},preferred,${offset}x0,1" 2>/dev/null
    local w
    w=$(get_monitors | jq -r --arg n "$out" '.[] | select(.name==$n) | .width // 1920')
    offset=$((offset + w))
  done < <(external_outputs)
}

# ---------------------------------------------------------------------------
# Subcomandos
# ---------------------------------------------------------------------------

cmd_list() {
  echo "=== Monitores ativos ==="
  get_monitors | jq -r '.[] | "  \(.name): \(.width)x\(.height)@\(.refreshRate|floor)Hz pos=\(.x)x\(.y) scale=\(.scale) enabled=\(if .disabled then "NÃO" else "SIM" end)"'
  echo ""
  echo "Modo salvo: $(read_mode)"
  echo "Notebook:   $(is_notebook && echo SIM || echo NÃO)"
}

cmd_mode() {
  local mode="${1:-}"
  local count
  count=$(monitor_count)

  if [[ -z "$mode" ]]; then
    echo "Uso: kryonix-monitors mode <extend|duplicate|internal|external|toggle>" >&2
    exit 1
  fi

  if [[ "$mode" == "toggle" ]]; then
    local current
    current=$(detect_current_mode)
    mode=$(next_mode "$current")
  fi

  if [[ "$count" -le 1 ]] && [[ "$mode" != "extend" ]]; then
    notify "Apenas 1 monitor detectado — modo '$mode' não aplicável"
    echo "Apenas 1 monitor conectado." >&2
    exit 0
  fi

  local internal
  internal=$(internal_output)

  case "$mode" in
    extend)
      echo "Modo: Estender"
      arrange_side_by_side
      notify "Modo estendido (lado a lado)"
      ;;

    duplicate)
      echo "Modo: Duplicar/Espelhar"
      if [[ -z "$internal" ]]; then
        # Desktop sem eDP: usa primeiro externo como fonte
        local outputs=()
        while IFS= read -r o; do outputs+=("$o"); done < <(active_outputs)
        local source="${outputs[0]}"
        for out in "${outputs[@]:1}"; do
          # Sintaxe correta do Hyprland: 5º campo mirror,<source>
          hyprctl keyword monitor "${out},preferred,auto,1,mirror,${source}" 2>/dev/null
          notify "Duplicando em ${out}" "Espelhando ${source}"
        done
      else
        # Notebook: espelha todos externos no eDP
        while IFS= read -r out; do
          [[ -z "$out" ]] && continue
          # Sintaxe correta: monitor=<ext>,preferred,auto,1,mirror,<internal>
          hyprctl keyword monitor "${out},preferred,auto,1,mirror,${internal}" 2>/dev/null
        done < <(external_outputs)
        notify "Modo espelho" "Externos espelhando ${internal}"
      fi
      ;;

    internal)
      echo "Modo: Só tela interna"
      if [[ -z "$internal" ]]; then
        notify "Sem tela interna detectada (sem eDP-*)"
        echo "Nenhum output eDP detectado." >&2
        exit 1
      fi
      while IFS= read -r out; do
        [[ -z "$out" ]] && continue
        hyprctl keyword monitor "${out},disabled" 2>/dev/null
      done < <(external_outputs)
      hyprctl keyword monitor "${internal},preferred,0x0,1" 2>/dev/null
      notify "Só tela interna" "${internal} ativado; externos desligados"
      ;;

    external)
      echo "Modo: Só monitor externo"
      local ext_list=()
      while IFS= read -r o; do [[ -n "$o" ]] && ext_list+=("$o"); done < <(external_outputs)

      if [[ "${#ext_list[@]}" -eq 0 ]]; then
        notify "Nenhum monitor externo detectado"
        echo "Nenhum output externo detectado." >&2
        exit 1
      fi

      if [[ -n "$internal" ]]; then
        hyprctl keyword monitor "${internal},disabled" 2>/dev/null
      fi
      local offset=0
      for out in "${ext_list[@]}"; do
        hyprctl keyword monitor "${out},preferred,${offset}x0,1" 2>/dev/null
        local w
        w=$(get_monitors | jq -r --arg n "$out" '.[] | select(.name==$n) | .width // 1920')
        offset=$((offset + w))
      done
      notify "Só monitor externo" "${ext_list[*]}"
      ;;

    *)
      echo "Modo desconhecido: $mode (opções: extend, duplicate, internal, external, toggle)" >&2
      exit 1
      ;;
  esac

  save_mode "$mode"
}

cmd_primary() {
  local output="${1:-}"
  if [[ -z "$output" ]]; then
    echo "Uso: kryonix-monitors primary <output>" >&2
    exit 1
  fi

  # Move workspace 1 para o monitor primário escolhido
  hyprctl dispatch moveworkspacetomonitor "1 ${output}" 2>/dev/null || true
  notify "Monitor primário" "${output} definido como primário (workspace 1 movido)"
  echo "Monitor primário: $output"
}

cmd_resolution() {
  local output="${1:-}" res="${2:-}"
  if [[ -z "$output" || -z "$res" ]]; then
    echo "Uso: kryonix-monitors resolution <output> <WxH[@Hz]>" >&2
    exit 1
  fi

  local pos scale
  pos=$(get_monitors | jq -r --arg n "$output" '.[] | select(.name==$n) | "\(.x)x\(.y)"')
  scale=$(get_monitors | jq -r --arg n "$output" '.[] | select(.name==$n) | .scale // 1')

  hyprctl keyword monitor "${output},${res},${pos},${scale}" 2>/dev/null
  notify "Resolução alterada" "${output} → ${res}"
  echo "Resolução de $output alterada para $res"
}

cmd_position() {
  local output="${1:-}" pos="${2:-}"
  if [[ -z "$output" || -z "$pos" ]]; then
    echo "Uso: kryonix-monitors position <output> <XxY>" >&2
    exit 1
  fi

  local res scale
  res=$(get_monitors | jq -r --arg n "$output" '.[] | select(.name==$n) | "\(.width)x\(.height)@\(.refreshRate|floor)"')
  scale=$(get_monitors | jq -r --arg n "$output" '.[] | select(.name==$n) | .scale // 1')

  hyprctl keyword monitor "${output},${res},${pos},${scale}" 2>/dev/null
  notify "Posição alterada" "${output} → ${pos}"
  echo "Posição de $output alterada para $pos"
}

cmd_scale() {
  local output="${1:-}" scale="${2:-}"
  if [[ -z "$output" || -z "$scale" ]]; then
    echo "Uso: kryonix-monitors scale <output> <fator>" >&2
    exit 1
  fi

  local res pos
  res=$(get_monitors | jq -r --arg n "$output" '.[] | select(.name==$n) | "\(.width)x\(.height)@\(.refreshRate|floor)"')
  pos=$(get_monitors | jq -r --arg n "$output" '.[] | select(.name==$n) | "\(.x)x\(.y)"')

  hyprctl keyword monitor "${output},${res},${pos},${scale}" 2>/dev/null
  notify "Escala alterada" "${output} → ${scale}x"
  echo "Escala de $output alterada para ${scale}x"
}

cmd_swap() {
  local count
  count=$(monitor_count)
  if [[ "$count" -lt 2 ]]; then
    notify "Apenas 1 monitor — swap não disponível"
    echo "Precisa de pelo menos 2 monitores para fazer swap." >&2
    exit 1
  fi

  # Lê as posições dos 2 primeiros monitores e inverte
  local mon_a mon_b pos_a pos_b res_a res_b scale_a scale_b
  mon_a=$(get_monitors | jq -r '.[0].name')
  mon_b=$(get_monitors | jq -r '.[1].name')
  pos_a=$(get_monitors | jq -r '.[0] | "\(.x)x\(.y)"')
  pos_b=$(get_monitors | jq -r '.[1] | "\(.x)x\(.y)"')
  res_a=$(get_monitors | jq -r '.[0] | "\(.width)x\(.height)@\(.refreshRate|floor)"')
  res_b=$(get_monitors | jq -r '.[1] | "\(.width)x\(.height)@\(.refreshRate|floor)"')
  scale_a=$(get_monitors | jq -r '.[0].scale // 1')
  scale_b=$(get_monitors | jq -r '.[1].scale // 1')

  hyprctl keyword monitor "${mon_a},${res_a},${pos_b},${scale_a}" 2>/dev/null
  hyprctl keyword monitor "${mon_b},${res_b},${pos_a},${scale_b}" 2>/dev/null

  notify "Posição trocada" "${mon_a} ↔ ${mon_b}"
  echo "Posições trocadas: $mon_a ↔ $mon_b"
}

cmd_menu() {
  local count
  count=$(monitor_count)
  local current
  current=$(detect_current_mode)

  # Opções base
  local options="🖥️  Estender (lado a lado)\n🪞  Duplicar (espelhar)\n💻  Só tela interna\n📺  Só monitor externo"
  if [[ "$count" -ge 2 ]]; then
    options+="\n🔄  Trocar posição dos monitores"
  fi
  options+="\n⚙️  Resolução...\n📊  Listar monitores"

  local choice
  choice=$(printf '%b' "$options" | rofi -dmenu -i -p "🖥️ Monitor ($current)" -theme-str 'window {width: 400px;}') || exit 0

  case "$choice" in
    "🖥️  Estender"*)    cmd_mode extend ;;
    "🪞  Duplicar"*)    cmd_mode duplicate ;;
    "💻  Só tela"*)     cmd_mode internal ;;
    "📺  Só monitor"*)  cmd_mode external ;;
    "🔄  Trocar"*)      cmd_swap ;;
    "⚙️  Resolução"*)   cmd_menu_resolution ;;
    "📊  Listar"*)      cmd_list | rofi -dmenu -p "Monitores" 2>/dev/null || true ;;
  esac
}

cmd_menu_resolution() {
  # Gera submenu de resoluções disponíveis por monitor
  local entries=""
  while IFS= read -r mon; do
    local modes current_res
    current_res=$(get_monitors | jq -r --arg n "$mon" '.[] | select(.name==$n) | "\(.width)x\(.height)@\(.refreshRate|floor)Hz"')
    # availableModes vem como array de strings no hyprctl monitors -j
    while IFS= read -r mode; do
      [[ -z "$mode" ]] && continue
      local marker=""
      [[ "$mode" == "${current_res%Hz}"* ]] && marker=" ✓"
      entries+="${mon}: ${mode}${marker}\n"
    done < <(get_monitors | jq -r --arg n "$mon" '.[] | select(.name==$n) | .availableModes[]? // empty')
  done < <(active_outputs)

  [[ -z "$entries" ]] && {
    notify "Modos disponíveis" "Nenhum modo disponível via hyprctl"
    return
  }

  local choice
  choice=$(printf '%b' "$entries" | rofi -dmenu -i -p "⚙️ Resolução") || return

  # Parseia "OUTPUT: WxH@Hz ✓" → output e resolução
  local out res
  out=$(echo "$choice" | cut -d: -f1 | xargs)
  res=$(echo "$choice" | cut -d: -f2- | sed 's/ ✓//' | xargs)

  cmd_resolution "$out" "$res"
}

cmd_restore() {
  local mode
  mode=$(read_mode)
  echo "Restaurando modo: $mode"
  # Pequeno delay para garantir que o Hyprland inicializou os outputs
  sleep 1
  cmd_mode "$mode"
}

# ---------------------------------------------------------------------------
# Dispatcher principal
# ---------------------------------------------------------------------------
main() {
  local subcmd="${1:-list}"
  shift 2>/dev/null || true

  case "$subcmd" in
    list|"")        cmd_list ;;
    mode)           cmd_mode "$@" ;;
    primary)        cmd_primary "$@" ;;
    resolution)     cmd_resolution "$@" ;;
    position)       cmd_position "$@" ;;
    scale)          cmd_scale "$@" ;;
    swap)           cmd_swap ;;
    menu)           cmd_menu ;;
    restore)        cmd_restore ;;
    help|--help|-h)
      echo "Uso: kryonix-monitors [subcomando] [args]"
      echo ""
      echo "Subcomandos:"
      echo "  (sem args)              Lista monitores ativos"
      echo "  mode <modo>             Muda modo: extend|duplicate|internal|external|toggle"
      echo "  primary <output>        Define monitor primário"
      echo "  resolution <out> <res>  Muda resolução (ex: 1920x1080@60)"
      echo "  position <out> <pos>    Reposiciona monitor (ex: 1920x0)"
      echo "  scale <out> <fator>     Muda escala (ex: 1.25)"
      echo "  swap                    Troca posição entre 2 monitores"
      echo "  menu                    Menu rofi interativo"
      echo "  restore                 Restaura último modo salvo"
      ;;
    *)
      echo "Subcomando desconhecido: $subcmd" >&2
      echo "Use 'kryonix-monitors help' para ver as opções." >&2
      exit 1
      ;;
  esac
}

main "$@"
