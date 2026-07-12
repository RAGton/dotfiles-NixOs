#!/usr/bin/env bash
set -u
set -o pipefail

HOST_EXPECTED="${HOST_EXPECTED:-RVE-GLACIER}"
BRIDGE_EXPECTED="${BRIDGE_EXPECTED:-br-glacier-lan}"
PHY_IFACE_EXPECTED="${PHY_IFACE_EXPECTED:-enp6s0}"
LAN_IP_EXPECTED="${LAN_IP_EXPECTED:-10.0.0.2}"
GATEWAY_EXPECTED="${GATEWAY_EXPECTED:-10.0.0.1}"
SSH_PORT_EXPECTED="${SSH_PORT_EXPECTED:-2224}"
FLAKE_PATH="${FLAKE_PATH:-/etc/kryonix}"
FLAKE_HOST="${FLAKE_HOST:-glacier}"
BOOTLOADER_NAME_EXPECTED="${BOOTLOADER_NAME_EXPECTED:-NixOS-boot}"

BRAIN_URL="${BRAIN_URL:-http://127.0.0.1:8000}"
OLLAMA_URL="${OLLAMA_URL:-http://127.0.0.1:11434}"

PASS=0
WARN=0
FAIL=0

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '\033[32m[PASS]\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$*"; WARN=$((WARN+1)); }
fail() { printf '\033[31m[FAIL]\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }
info() { printf '\033[36m[INFO]\033[0m %s\n' "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

section() {
  echo
  bold "================================================================"
  bold "$1"
  bold "================================================================"
}

run_timeout() {
  local seconds="$1"
  shift
  if have timeout; then
    timeout "$seconds" "$@"
  else
    "$@"
  fi
}

check_cmd() {
  local name="$1"
  local cmd="$2"
  if bash -lc "$cmd" >/dev/null 2>&1; then
    ok "$name"
  else
    fail "$name"
  fi
}

check_warn_cmd() {
  local name="$1"
  local cmd="$2"
  if bash -lc "$cmd" >/dev/null 2>&1; then
    ok "$name"
  else
    warn "$name"
  fi
}

section "GLACIER DOCTOR - contexto"
date
echo "Host esperado:      $HOST_EXPECTED"
echo "Bridge esperada:    $BRIDGE_EXPECTED"
echo "Interface física:   $PHY_IFACE_EXPECTED"
echo "IP LAN esperado:    $LAN_IP_EXPECTED"
echo "Gateway esperado:   $GATEWAY_EXPECTED"
echo "SSH esperado:       $SSH_PORT_EXPECTED"
echo "Flake:              $FLAKE_PATH#$FLAKE_HOST"
echo

section "1. Identidade do sistema"

STATIC_HOST="$(hostnamectl --static 2>/dev/null || hostname)"
TRANSIENT_HOST="$(hostnamectl --transient 2>/dev/null || true)"
OS_PRETTY="$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"' || true)"
KERNEL="$(uname -r)"

echo "Static hostname:    ${STATIC_HOST:-unknown}"
echo "Transient hostname: ${TRANSIENT_HOST:-none}"
echo "OS:                 ${OS_PRETTY:-unknown}"
echo "Kernel:             $KERNEL"

if [[ "$STATIC_HOST" == "$HOST_EXPECTED" ]]; then
  ok "hostname está como $HOST_EXPECTED"
else
  warn "hostname está '$STATIC_HOST', esperado '$HOST_EXPECTED'"
fi

if [[ "$TRANSIENT_HOST" == "nixos" ]]; then
  warn "transient hostname ainda aparece como 'nixos'"
elif [[ -n "$TRANSIENT_HOST" ]]; then
  ok "transient hostname não está genérico: $TRANSIENT_HOST"
else
  ok "sem transient hostname conflitante"
fi

section "2. Geração NixOS / boot atual"

RUN_SYSTEM="$(readlink -f /run/current-system 2>/dev/null || true)"
PROFILE_SYSTEM="$(readlink -f /nix/var/nix/profiles/system 2>/dev/null || true)"

echo "/run/current-system:              $RUN_SYSTEM"
echo "/nix/var/nix/profiles/system:     $PROFILE_SYSTEM"

if [[ -n "$RUN_SYSTEM" && -n "$PROFILE_SYSTEM" && "$RUN_SYSTEM" == "$PROFILE_SYSTEM" ]]; then
  ok "boot atual usa a mesma geração do perfil system"
else
  fail "boot atual NÃO usa a mesma geração do perfil system"
  warn "isso normalmente indica que bootou em geração antiga ou bootloader errado"
fi

if [[ "$RUN_SYSTEM" == *"$HOST_EXPECTED"* || "$RUN_SYSTEM" == *"GLACIER"* || "$RUN_SYSTEM" == *"glacier"* ]]; then
  ok "run current-system parece ser geração Glacier"
else
  warn "run current-system não mostra nome Glacier/RVE-GLACIER"
fi

section "3. Bootloader UEFI / GRUB"

if have efibootmgr; then
  EFIBOOT="$(efibootmgr -v 2>/dev/null || true)"
  BOOTCURRENT="$(echo "$EFIBOOT" | awk -F': ' '/BootCurrent:/ {print $2}' | head -1)"
  BOOTORDER="$(echo "$EFIBOOT" | awk -F': ' '/BootOrder:/ {print $2}' | head -1)"
  EXPECTED_BOOTNUM="$(echo "$EFIBOOT" | awk -v name="$BOOTLOADER_NAME_EXPECTED" '$0 ~ name {gsub(/^Boot/,"",$1); gsub(/\*/,"",$1); print $1; exit}')"

  echo "BootCurrent: $BOOTCURRENT"
  echo "BootOrder:   $BOOTORDER"
  echo "Boot esperado por nome '$BOOTLOADER_NAME_EXPECTED': ${EXPECTED_BOOTNUM:-não encontrado}"

  if [[ -n "$EXPECTED_BOOTNUM" ]]; then
    ok "entrada UEFI $BOOTLOADER_NAME_EXPECTED existe: Boot$EXPECTED_BOOTNUM"
    if [[ "$BOOTCURRENT" == "$EXPECTED_BOOTNUM" ]]; then
      ok "boot atual veio pelo $BOOTLOADER_NAME_EXPECTED"
    else
      warn "boot atual veio pelo Boot$BOOTCURRENT, não pelo Boot$EXPECTED_BOOTNUM"
    fi

    if [[ "$BOOTORDER" == "$EXPECTED_BOOTNUM"* ]]; then
      ok "$BOOTLOADER_NAME_EXPECTED está primeiro no BootOrder"
    else
      warn "$BOOTLOADER_NAME_EXPECTED não está primeiro no BootOrder"
    fi
  else
    fail "entrada UEFI $BOOTLOADER_NAME_EXPECTED não encontrada"
  fi

  if echo "$EFIBOOT" | grep -q "Linux Boot Manager"; then
    warn "também existe Linux Boot Manager/systemd-boot; pode competir com GRUB"
  else
    ok "não encontrei Linux Boot Manager concorrente"
  fi
else
  warn "efibootmgr não encontrado"
fi

if [[ -f /boot/grub/grub.cfg ]]; then
  ok "/boot/grub/grub.cfg existe"
  if grep -q "$PROFILE_SYSTEM" /boot/grub/grub.cfg 2>/dev/null; then
    ok "GRUB contém a geração atual do perfil system"
  else
    warn "GRUB pode não conter exatamente o profile system atual"
  fi
else
  fail "/boot/grub/grub.cfg não existe"
fi

if findmnt /boot >/dev/null 2>&1; then
  ok "/boot está montado"
  findmnt /boot
else
  fail "/boot não está montado"
fi

section "4. Systemd - jobs, falhas e unidades suspeitas"

JOBS="$(systemctl list-jobs --no-pager 2>/dev/null || true)"
echo "$JOBS"

if echo "$JOBS" | grep -q "No jobs running"; then
  ok "sem jobs systemd pendurados"
else
  warn "existem jobs systemd em andamento"
fi

FAILED="$(systemctl --failed --no-pager 2>/dev/null || true)"
echo "$FAILED"

if echo "$FAILED" | grep -q "0 loaded units listed"; then
  ok "sem units failed"
else
  fail "existem units failed"
fi

if systemctl list-unit-files | grep -q '^tailscale-autoconnect.service'; then
  TS_AUTO_STATE="$(systemctl is-active tailscale-autoconnect.service 2>/dev/null || true)"
  warn "tailscale-autoconnect.service existe; estado: $TS_AUTO_STATE"

  if systemctl cat tailscale-autoconnect.service 2>/dev/null | grep -q 'tskey-auth'; then
    fail "tailscale-autoconnect contém auth key exposta no unit/script"
  fi

  if systemctl cat tailscale-autoconnect.service 2>/dev/null | grep -q 'TimeoutStartSec'; then
    ok "tailscale-autoconnect tem TimeoutStartSec"
  else
    warn "tailscale-autoconnect não tem TimeoutStartSec; pode travar rebuild/boot"
  fi

  if systemctl cat tailscale-autoconnect.service 2>/dev/null | grep -q 'RemainAfterExit=true'; then
    warn "tailscale-autoconnect usa RemainAfterExit=true"
  fi
else
  ok "tailscale-autoconnect.service não existe"
fi

section "5. Rede LAN estilo Proxmox / Bridge"

echo
ip -br addr || true
echo
ip route || true

if ip link show "$BRIDGE_EXPECTED" >/dev/null 2>&1; then
  ok "bridge $BRIDGE_EXPECTED existe"
else
  fail "bridge $BRIDGE_EXPECTED não existe"
fi

if ip link show "$PHY_IFACE_EXPECTED" >/dev/null 2>&1; then
  ok "interface física $PHY_IFACE_EXPECTED existe"
else
  fail "interface física $PHY_IFACE_EXPECTED não existe"
fi

if bridge link 2>/dev/null | grep -q "$PHY_IFACE_EXPECTED.*master $BRIDGE_EXPECTED"; then
  ok "$PHY_IFACE_EXPECTED está como porta da bridge $BRIDGE_EXPECTED"
else
  warn "$PHY_IFACE_EXPECTED pode não estar anexada corretamente na bridge $BRIDGE_EXPECTED"
fi

if ip -4 addr show dev "$BRIDGE_EXPECTED" 2>/dev/null | grep -q "${LAN_IP_EXPECTED}/"; then
  ok "$BRIDGE_EXPECTED tem IP esperado $LAN_IP_EXPECTED"
else
  fail "$BRIDGE_EXPECTED não tem IP esperado $LAN_IP_EXPECTED"
fi

if ip -4 addr show dev "$PHY_IFACE_EXPECTED" 2>/dev/null | grep -q 'inet '; then
  warn "$PHY_IFACE_EXPECTED tem IPv4 direto; em modelo Proxmox o IP deve ficar só na bridge"
else
  ok "$PHY_IFACE_EXPECTED não tem IPv4 direto"
fi

if ip route | grep -q "default via $GATEWAY_EXPECTED dev $BRIDGE_EXPECTED"; then
  ok "rota default via $GATEWAY_EXPECTED dev $BRIDGE_EXPECTED"
else
  warn "rota default não está claramente via $GATEWAY_EXPECTED dev $BRIDGE_EXPECTED"
fi

check_warn_cmd "ping gateway $GATEWAY_EXPECTED" "ping -c 2 -W 2 $GATEWAY_EXPECTED"
check_warn_cmd "ping internet IPv4 1.1.1.1" "ping -c 2 -W 2 1.1.1.1"
check_warn_cmd "DNS resolve google.com" "getent hosts google.com"

if ss -ltn 2>/dev/null | grep -q ":$SSH_PORT_EXPECTED "; then
  ok "SSH escutando na porta $SSH_PORT_EXPECTED"
else
  fail "SSH não parece escutar na porta $SSH_PORT_EXPECTED"
fi

section "6. Tailscale"

if systemctl list-unit-files | grep -q '^tailscaled.service'; then
  TS_STATE="$(systemctl is-active tailscaled.service 2>/dev/null || true)"
  if [[ "$TS_STATE" == "active" ]]; then
    ok "tailscaled.service ativo"
  else
    warn "tailscaled.service estado: $TS_STATE"
  fi
else
  warn "tailscaled.service não encontrado"
fi

if have tailscale; then
  if run_timeout 5 tailscale status >/tmp/glacier-tailscale-status.txt 2>&1; then
    ok "tailscale status respondeu"
    head -30 /tmp/glacier-tailscale-status.txt
  else
    warn "tailscale status falhou ou demorou"
    cat /tmp/glacier-tailscale-status.txt 2>/dev/null || true
  fi
else
  warn "comando tailscale não encontrado"
fi

section "7. NVIDIA / GPU / CUDA"

if have nvidia-smi; then
  if nvidia-smi >/tmp/glacier-nvidia-smi.txt 2>&1; then
    ok "nvidia-smi funcionando"
    nvidia-smi --query-gpu=name,driver_version,memory.total,memory.used --format=csv,noheader 2>/dev/null || head -20 /tmp/glacier-nvidia-smi.txt
  else
    fail "nvidia-smi existe, mas falhou"
    cat /tmp/glacier-nvidia-smi.txt
  fi
else
  warn "nvidia-smi não encontrado"
fi

if lsmod | grep -q '^nvidia'; then
  ok "módulo nvidia carregado"
else
  warn "módulo nvidia não parece carregado"
fi

section "8. Ollama"

if systemctl list-unit-files | grep -q '^ollama.service'; then
  OLLAMA_STATE="$(systemctl is-active ollama.service 2>/dev/null || true)"
  if [[ "$OLLAMA_STATE" == "active" ]]; then
    ok "ollama.service ativo"
  else
    warn "ollama.service estado: $OLLAMA_STATE"
  fi
else
  warn "ollama.service não encontrado"
fi

if ss -ltn 2>/dev/null | grep -q ':11434 '; then
  ok "porta Ollama 11434 escutando"
else
  warn "porta Ollama 11434 não está escutando"
fi

if have curl; then
  if run_timeout 5 curl -fsS "$OLLAMA_URL/api/tags" >/tmp/glacier-ollama-tags.json 2>&1; then
    ok "Ollama API respondeu em $OLLAMA_URL"
    head -c 500 /tmp/glacier-ollama-tags.json
    echo
  else
    warn "Ollama API não respondeu em $OLLAMA_URL"
  fi
else
  warn "curl não encontrado"
fi

section "9. Kryonix Brain / LightRAG / MCP"

if ss -ltn 2>/dev/null | grep -q ':8000 '; then
  ok "porta Brain API 8000 escutando"
else
  warn "porta Brain API 8000 não está escutando"
fi

if have curl; then
  if run_timeout 5 curl -fsS "$BRAIN_URL/health" >/tmp/glacier-brain-health.txt 2>&1; then
    ok "Brain API /health respondeu"
    cat /tmp/glacier-brain-health.txt
    echo
  else
    warn "Brain API /health não respondeu em $BRAIN_URL/health"
  fi

  if run_timeout 5 curl -fsS "$BRAIN_URL/stats" >/tmp/glacier-brain-stats.txt 2>&1; then
    ok "Brain API /stats respondeu"
    head -c 800 /tmp/glacier-brain-stats.txt
    echo
  else
    warn "Brain API /stats não respondeu em $BRAIN_URL/stats"
  fi
fi

if have kryonix; then
  check_warn_cmd "kryonix brain health" "run_timeout 15 kryonix brain health"
  check_warn_cmd "kryonix brain stats" "run_timeout 15 kryonix brain stats"
  check_warn_cmd "kryonix mcp check" "run_timeout 15 kryonix mcp check"
else
  warn "CLI kryonix não encontrada no PATH"
fi

section "10. Storage / discos"

lsblk -f || true
echo
df -hT / /boot /nix/store 2>/dev/null || true

ROOT_USE="$(df -P / | awk 'NR==2 {gsub(/%/,"",$5); print $5}')"
if [[ -n "$ROOT_USE" && "$ROOT_USE" -lt 85 ]]; then
  ok "uso de / abaixo de 85%: ${ROOT_USE}%"
else
  warn "uso de / alto ou desconhecido: ${ROOT_USE:-unknown}%"
fi

if findmnt /storage >/dev/null 2>&1; then
  ok "/storage montado"
  df -hT /storage || true
else
  warn "/storage não está montado"
fi

if findmnt /home >/dev/null 2>&1; then
  ok "/home possui mount explícito"
  findmnt /home
else
  warn "/home não possui mount explícito separado"
fi

if have zpool; then
  if zpool status >/dev/null 2>&1; then
    ok "zpool status executou com sucesso"
    sudo zpool status -v || true
  else
    warn "ZFS falhou ou não há pools configuradas"
  fi
else
  warn "zpool não encontrado"
fi

if have zfs; then
  sudo zfs list -o name,used,avail,refer,mountpoint,mounted || true
else
  warn "zfs não encontrado"
fi

section "11. Flake / Nix sanity"

if [[ -d "$FLAKE_PATH" ]]; then
  ok "flake path existe: $FLAKE_PATH"
  cd "$FLAKE_PATH"

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    info "git status:"
    git status --short || true
    info "submodules:"
    git submodule status --recursive 2>/dev/null || true
  else
    warn "$FLAKE_PATH não parece ser repo git"
  fi

  if have nix; then
    if [[ "${DEEP:-0}" == "1" ]]; then
      info "DEEP=1 habilitado: rodando nixos-rebuild build"
      if run_timeout 1800 sudo nixos-rebuild build --flake "$FLAKE_PATH#$FLAKE_HOST" -L --show-trace; then
        ok "nixos-rebuild build passou"
      else
        fail "nixos-rebuild build falhou"
      fi
    else
      warn "build profundo não executado. Use DEEP=1 para rodar nixos-rebuild build."
    fi
  else
    fail "nix não encontrado"
  fi
else
  fail "flake path não existe: $FLAKE_PATH"
fi

section "12. Logs recentes importantes"

info "warnings/errors recentes do boot:"
journalctl -b -p warning..alert --no-pager -n 80 2>/dev/null || true

section "RESUMO"

echo "PASS: $PASS"
echo "WARN: $WARN"
echo "FAIL: $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  echo
  fail "Glacier tem falhas críticas para corrigir"
  exit 2
elif [[ "$WARN" -gt 0 ]]; then
  echo
  warn "Glacier está funcional, mas tem avisos importantes"
  exit 1
else
  echo
  ok "Glacier passou nos testes principais"
  exit 0
fi
