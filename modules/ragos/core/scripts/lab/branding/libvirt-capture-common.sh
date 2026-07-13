#!/usr/bin/env bash
# Purpose: Funcoes compartilhadas para capturas visuais do BrandLab via libvirt
# Category: branding
# Safety: safe
# Expected environment: laboratorio local com bash, virsh e nix disponiveis
# Requires: bash, virsh, nix

set -euo pipefail

brandlab_repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd
}

brandlab_log() {
  printf '[info] %s\n' "$*"
}

brandlab_warn() {
  printf '[warn] %s\n' "$*" >&2
}

brandlab_die() {
  printf '[error] %s\n' "$*" >&2
  exit 1
}

brandlab_require_cmd() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || brandlab_die "comando obrigatorio ausente: ${cmd}"
  done
}

brandlab_with_image_tools() {
  if command -v magick >/dev/null 2>&1 && command -v tesseract >/dev/null 2>&1; then
    "$@"
    return
  fi

  nix \
    --extra-experimental-features nix-command \
    --extra-experimental-features flakes \
    shell nixpkgs#imagemagick nixpkgs#tesseract -c "$@"
}

brandlab_domain_running() {
  local libvirt_uri="$1"
  local domain="$2"
  [[ "$(virsh --connect "$libvirt_uri" domstate "$domain" 2>/dev/null | tr '[:upper:]' '[:lower:]')" == "running" ]]
}

brandlab_domain_exists() {
  local libvirt_uri="$1"
  local domain="$2"
  virsh --connect "$libvirt_uri" dominfo "$domain" >/dev/null 2>&1
}

brandlab_take_screenshot() {
  local libvirt_uri="$1"
  local domain="$2"
  local output_png="$3"

  rm -f "$output_png"
  virsh --connect "$libvirt_uri" screenshot "$domain" "$output_png" >/dev/null 2>&1 \
    || brandlab_die "falha ao capturar screenshot de ${domain}"
  [[ -s "$output_png" ]] || brandlab_die "screenshot vazio para ${domain}: ${output_png}"
}

brandlab_write_ocr() {
  local image_path="$1"
  local ocr_path="$2"

  brandlab_with_image_tools bash -lc '
    image_path="$1"
    ocr_path="$2"
    preprocessed="$ocr_path.pre.png"
    magick "$image_path" -resize 300% -colorspace Gray -auto-level -sharpen 0x1 "$preprocessed"
    tesseract "$preprocessed" stdout >"$ocr_path.tmp" 2>/dev/null || true
    tr -d "\f" <"$ocr_path.tmp" >"$ocr_path"
    rm -f "$ocr_path.tmp" "$preprocessed"
  ' _ "$image_path" "$ocr_path"
}

brandlab_image_dimensions() {
  local image_path="$1"

  brandlab_with_image_tools bash -lc '
    image_path="$1"
    magick identify -format "%w %h" "$image_path"
  ' _ "$image_path"
}

brandlab_image_mean() {
  local image_path="$1"

  brandlab_with_image_tools bash -lc '
    image_path="$1"
    magick "$image_path" -colorspace Gray -format "%[fx:mean]" info:
  ' _ "$image_path"
}

brandlab_image_stddev() {
  local image_path="$1"

  brandlab_with_image_tools bash -lc '
    image_path="$1"
    magick "$image_path" -colorspace Gray -format "%[fx:standard_deviation]" info:
  ' _ "$image_path"
}

brandlab_ocr_inactive_output() {
  local ocr_path="$1"
  grep -Fqi 'Display output is not active.' "$ocr_path"
}

brandlab_latest_capture_for_surface() {
  local screenshots_dir="$1"
  local surface="$2"

  find "$screenshots_dir" -maxdepth 1 -type f -name "${surface}-*.meta.txt" -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr \
    | head -n 1 \
    | awk '{print $2}'
}

brandlab_set_meta_value() {
  local meta_path="$1"
  local key="$2"
  local value="$3"

  if grep -q "^${key}=" "$meta_path"; then
    sed -i "s#^${key}=.*#${key}=${value}#" "$meta_path"
  else
    printf '%s=%s\n' "$key" "$value" >>"$meta_path"
  fi
}

brandlab_meta_value() {
  local meta_path="$1"
  local key="$2"

  sed -n "s/^${key}=//p" "$meta_path" | head -n 1
}

brandlab_emit_capture_metadata() {
  local meta_path="$1"
  local surface="$2"
  local domain="$3"
  local image_path="$4"
  local ocr_path="$5"
  local capture_mode="$6"
  local inactive_output="$7"
  local width="$8"
  local height="$9"
  local grayscale_mean="${10}"
  local grayscale_stddev="${11}"
  local image_sha256="${12}"
  local surface_match="${13}"
  local surface_match_reason="${14}"

  cat >"$meta_path" <<EOF
surface=${surface}
domain=${domain}
captured_at=$(date --iso-8601=seconds)
capture_mode=${capture_mode}
image_path=${image_path}
ocr_path=${ocr_path}
inactive_output=${inactive_output}
width=${width}
height=${height}
grayscale_mean=${grayscale_mean}
grayscale_stddev=${grayscale_stddev}
image_sha256=${image_sha256}
surface_match=${surface_match}
surface_match_reason=${surface_match_reason}
EOF
}

brandlab_send_domain_keys() {
  local libvirt_uri="$1"
  local domain="$2"
  shift 2 || true

  virsh --connect "$libvirt_uri" send-key "$domain" --codeset linux "$@" >/dev/null 2>&1 \
    || brandlab_die "falha ao enviar teclas para ${domain}: $*"
  sleep 0.2
}

brandlab_send_key_csv() {
  local libvirt_uri="$1"
  local domain="$2"
  local csv="$3"
  local key

  [[ -n "$csv" ]] || return 0
  while IFS= read -r key; do
    [[ -n "$key" ]] || continue
    brandlab_send_domain_keys "$libvirt_uri" "$domain" "$key"
  done < <(tr ',' '\n' <<<"$csv")
}

brandlab_send_text_to_sddm() {
  local libvirt_uri="$1"
  local domain="$2"
  local text="$3"
  local index char upper

  for (( index = 0; index < ${#text}; index++ )); do
    char="${text:index:1}"
    case "$char" in
      [a-z])
        upper="${char^^}"
        brandlab_send_domain_keys "$libvirt_uri" "$domain" "KEY_${upper}"
        ;;
      [A-Z])
        brandlab_send_domain_keys "$libvirt_uri" "$domain" KEY_LEFTSHIFT "KEY_${char}"
        ;;
      [0-9])
        brandlab_send_domain_keys "$libvirt_uri" "$domain" "KEY_${char}"
        ;;
      ' ')
        brandlab_send_domain_keys "$libvirt_uri" "$domain" KEY_SPACE
        ;;
      '/')
        brandlab_send_domain_keys "$libvirt_uri" "$domain" KEY_SLASH
        ;;
      '.')
        brandlab_send_domain_keys "$libvirt_uri" "$domain" KEY_DOT
        ;;
      '-')
        brandlab_send_domain_keys "$libvirt_uri" "$domain" KEY_MINUS
        ;;
      '=')
        brandlab_send_domain_keys "$libvirt_uri" "$domain" KEY_EQUAL
        ;;
      '!')
        brandlab_send_domain_keys "$libvirt_uri" "$domain" KEY_LEFTSHIFT KEY_1
        ;;
      *)
        brandlab_die "caractere ainda nao suportado para automacao do SDDM: ${char}"
        ;;
    esac
  done
}

brandlab_send_password_to_sddm() {
  local libvirt_uri="$1"
  local domain="$2"
  local password="$3"

  brandlab_send_text_to_sddm "$libvirt_uri" "$domain" "$password"
}

brandlab_expect() {
  if command -v expect >/dev/null 2>&1; then
    expect "$@"
    return
  fi

  nix \
    --extra-experimental-features nix-command \
    --extra-experimental-features flakes \
    shell nixpkgs#expect -c expect "$@"
}

brandlab_run_serial_command() {
  local libvirt_uri="$1"
  local domain="$2"
  local login_user="$3"
  local login_password="$4"
  local timeout_seconds="$5"
  local output_log="$6"
  local command="$7"
  local command_b64

  command_b64="$(printf '%s' "$command" | base64 | tr -d '\n')"

  brandlab_expect <<EOF
set timeout ${timeout_seconds}
log_user 1
log_file -noappend "$output_log"
spawn virsh --connect "$libvirt_uri" console "$domain"
expect {
  -re {Connected to domain} {}
  timeout { puts stderr "timeout conectando ao console serial de $domain"; exit 1 }
}
sleep 2
send -- "\r"
expect {
  -re {login:} { set need_login 1 }
  -re {${login_user}@.*[#$]} { set need_login 0 }
  timeout {
    puts stderr "nao foi possivel detectar login serial ou shell pronta em $domain"
    send -- "\035"
    expect eof
    exit 1
  }
}
if {\$need_login} {
  send -- "${login_user}\r"
  expect {
    -re {(Password:|Senha:)} {}
    timeout {
      puts stderr "nao foi possivel detectar prompt de senha em $domain"
      send -- "\035"
      expect eof
      exit 1
    }
  }
  send -- "${login_password}\r"
  sleep 2
  send -- "\r"
  expect {
    -re {${login_user}@.*[#$]} {}
    -re {login:} {
      puts stderr "login serial falhou para ${login_user} em $domain"
      send -- "\035"
      expect eof
      exit 1
    }
    timeout {
      puts stderr "nao foi possivel detectar shell apos login em $domain"
      send -- "\035"
      expect eof
      exit 1
    }
  }
}
send -- "export SYSTEMD_PAGER=cat PAGER=cat\r"
send -- "stty -echo\r"
send -- "printf '%s' '${command_b64}' | base64 -d | bash -s; serial_status=\\\$?; echo __RAGOS_SERIAL_COMMAND_STATUS__:\\\$serial_status\r"
expect {
  -re {__RAGOS_SERIAL_COMMAND_STATUS__:0} {}
  -re {__RAGOS_SERIAL_COMMAND_STATUS__:[1-9][0-9]*} {
    puts stderr "comando serial falhou em $domain"
    send -- "\035"
    expect eof
    exit 1
  }
  timeout {
    puts stderr "timeout aguardando conclusao do comando serial em $domain"
    send -- "\035"
    expect eof
    exit 1
  }
}
send -- "stty echo\r"
send -- "\035"
expect eof
EOF
}

brandlab_verify_graphical_session_via_serial() {
  local libvirt_uri="$1"
  local domain="$2"
  local login_user="$3"
  local login_password="$4"
  local session_user="$5"
  local timeout_seconds="$6"
  local output_log="$7"

  brandlab_expect <<EOF
set timeout ${timeout_seconds}
log_user 1
log_file -noappend "$output_log"
spawn virsh --connect "$libvirt_uri" console "$domain"
expect {
  -re {Connected to domain} {}
  timeout { puts stderr "timeout conectando ao console serial de $domain"; exit 1 }
}
sleep 2
send -- "\r"
expect {
  -re {login:} { set need_login 1 }
  -re {${login_user}@.*[#$]} { set need_login 0 }
  timeout {
    puts stderr "nao foi possivel detectar login serial ou shell pronta em $domain"
    send -- "\035"
    expect eof
    exit 1
  }
}
if {\$need_login} {
  send -- "${login_user}\r"
  expect {
    -re {(Password:|Senha:)} {}
    timeout {
      puts stderr "nao foi possivel detectar prompt de senha em $domain"
      send -- "\035"
      expect eof
      exit 1
    }
  }
  send -- "${login_password}\r"
  sleep 2
  send -- "\r"
  expect {
    -re {${login_user}@.*[#$]} {}
    -re {login:} {
      puts stderr "login serial falhou para ${login_user} em $domain"
      send -- "\035"
      expect eof
      exit 1
    }
    timeout {
      puts stderr "nao foi possivel detectar shell apos login em $domain"
      send -- "\035"
      expect eof
      exit 1
    }
  }
}
send -- "export SYSTEMD_PAGER=cat PAGER=cat\r"
send -- "stty -echo\r"
send -- "echo '--- loginctl ---'\r"
send -- "loginctl list-sessions --no-legend || true\r"
send -- "loginctl show-user '${session_user}' --no-pager || true\r"
send -- "echo '--- graphical processes ---'\r"
send -- "if pgrep -u '${session_user}' -fa 'startplasma|plasma-session|plasmashell|kwin_wayland|ksmserver' >/tmp/ragos-graphical-procs.txt; then echo __RAGOS_GRAPHICAL_PROC_FOUND__; cat /tmp/ragos-graphical-procs.txt; else echo __RAGOS_GRAPHICAL_PROC_MISSING__; fi\r"
expect {
  -re {__RAGOS_GRAPHICAL_PROC_FOUND__} {}
  -re {__RAGOS_GRAPHICAL_PROC_MISSING__} {
    puts stderr "nao foi possivel provar sessao grafica do usuario ${session_user} em $domain"
    send -- "\035"
    expect eof
    exit 1
  }
  timeout {
    puts stderr "nao foi possivel provar sessao grafica do usuario ${session_user} em $domain"
    send -- "\035"
    expect eof
    exit 1
  }
}
send -- "stty echo\r"
send -- "echo __RAGOS_GRAPHICAL_SESSION_OK__\r"
expect {
  -re {__RAGOS_GRAPHICAL_SESSION_OK__} {}
  timeout {
    puts stderr "nao foi possivel concluir prova serial de sessao grafica em $domain"
    send -- "\035"
    expect eof
    exit 1
  }
}
send -- "\035"
expect eof
EOF
}

brandlab_classify_surface_match() {
  local ocr_path="$1"
  local expected_regex="$2"
  local reject_regex="$3"

  if [[ -n "$reject_regex" ]] && grep -Eiq "$reject_regex" "$ocr_path"; then
    printf 'rejected|reject_regex'
    return
  fi

  if [[ -n "$expected_regex" ]] && grep -Eiq "$expected_regex" "$ocr_path"; then
    printf 'expected|expected_regex'
    return
  fi

  printf 'unknown|no_regex_match'
}

brandlab_capture_current_surface() {
  local surface="$1"
  local libvirt_uri="$2"
  local domain="$3"
  local screenshots_dir="$4"
  local allow_inactive="$5"
  local expected_regex="$6"
  local reject_regex="$7"

  local stem image_path ocr_path meta_path width height mean stddev sha surface_match surface_match_reason match_payload
  mkdir -p "$screenshots_dir"

  brandlab_domain_exists "$libvirt_uri" "$domain" || brandlab_die "dominio inexistente: ${domain}"
  brandlab_domain_running "$libvirt_uri" "$domain" || brandlab_die "dominio nao esta rodando: ${domain}"

  stem="${surface}-${domain}-current"
  image_path="${screenshots_dir}/${stem}.png"
  ocr_path="${screenshots_dir}/${stem}.ocr.txt"
  meta_path="${screenshots_dir}/${stem}.meta.txt"

  brandlab_take_screenshot "$libvirt_uri" "$domain" "$image_path"
  brandlab_write_ocr "$image_path" "$ocr_path"

  read -r width height <<<"$(brandlab_image_dimensions "$image_path")"
  mean="$(brandlab_image_mean "$image_path")"
  stddev="$(brandlab_image_stddev "$image_path")"
  sha="$(sha256sum "$image_path" | awk '{print $1}')"

  if brandlab_ocr_inactive_output "$ocr_path"; then
    brandlab_emit_capture_metadata \
      "$meta_path" "$surface" "$domain" "$image_path" "$ocr_path" "virsh-screenshot" \
      "true" "$width" "$height" "$mean" "$stddev" "$sha" "rejected" "inactive_output"
    if [[ "$allow_inactive" != "true" ]]; then
      brandlab_die "captura real gerada, mas a saida grafica esta inativa: ${image_path}"
    fi
    brandlab_warn "captura gerada com saida grafica inativa: ${image_path}"
    return 0
  fi

  match_payload="$(brandlab_classify_surface_match "$ocr_path" "$expected_regex" "$reject_regex")"
  surface_match="${match_payload%%|*}"
  surface_match_reason="${match_payload#*|}"

  brandlab_emit_capture_metadata \
    "$meta_path" "$surface" "$domain" "$image_path" "$ocr_path" "virsh-screenshot" \
    "false" "$width" "$height" "$mean" "$stddev" "$sha" "$surface_match" "$surface_match_reason"

  case "$surface_match" in
    expected)
      brandlab_log "captura salva em ${image_path}"
      ;;
    unknown)
      brandlab_warn "captura salva, mas a superficie ainda exige revisao humana: ${image_path}"
      ;;
    rejected)
      if [[ "$allow_inactive" != "true" ]]; then
        brandlab_die "captura salva, mas o OCR indica superficie inesperada para ${surface}: ${image_path}"
      fi
      brandlab_warn "captura salva, mas o OCR indica superficie inesperada para ${surface}: ${image_path}"
      ;;
  esac
}

brandlab_wait_for_surface_match() {
  local surface="$1"
  local libvirt_uri="$2"
  local domain="$3"
  local screenshots_dir="$4"
  local wait_seconds="$5"
  local poll_seconds="$6"
  local expected_regex="$7"
  local reject_regex="$8"

  local deadline meta_path match
  deadline="$((SECONDS + wait_seconds))"

  while (( SECONDS < deadline )); do
    brandlab_capture_current_surface "$surface" "$libvirt_uri" "$domain" "$screenshots_dir" "true" "$expected_regex" "$reject_regex"
    meta_path="${screenshots_dir}/${surface}-${domain}-current.meta.txt"
    match="$(brandlab_meta_value "$meta_path" surface_match)"
    if [[ "$match" == "expected" ]]; then
      return 0
    fi
    sleep "$poll_seconds"
  done

  return 1
}
