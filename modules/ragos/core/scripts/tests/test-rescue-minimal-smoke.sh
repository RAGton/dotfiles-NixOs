#!/usr/bin/env bash
# Purpose: Validar postura operacional do perfil rescue-minimal
# Category: tests
# Safety: safe
# Expected environment: dev shell com Nix flakes
# Requires: nix

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
nix_cmd=(nix --extra-experimental-features "nix-command flakes")
rescue_cfg="path:$repo_root#nixosConfigurations.ragos-client-dev-rescue-minimal.config"

assert_eq() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  [[ "$expected" == "$actual" ]] || {
    echo "ASSERT FAIL [$label]: expected '$expected', got '$actual'" >&2
    exit 1
  }
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  grep -Fq "$needle" <<<"$haystack" || {
    echo "ASSERT FAIL [$label]: missing '$needle'" >&2
    exit 1
  }
}

eval_raw() {
  local attr="$1"
  "${nix_cmd[@]}" eval --raw "$rescue_cfg.$attr"
}

eval_bool() {
  local attr="$1"
  "${nix_cmd[@]}" eval "$rescue_cfg.$attr" | tr -d '\n'
}

echo "[1/4] garantir perfil sem stack grafica"
assert_eq "false" "$(eval_bool services.displayManager.sddm.enable)" "sddm disabled"
assert_eq "false" "$(eval_bool services.desktopManager.plasma6.enable)" "plasma6 disabled"
assert_eq "false" "$(eval_bool services.xserver.enable)" "xserver disabled"
assert_eq "false" "$(eval_bool boot.plymouth.enable)" "plymouth disabled"

echo "[2/4] garantir operacao em console e acesso remoto"
assert_eq "true" "$(eval_bool services.openssh.enable)" "openssh enabled"
assert_eq "multi-user.target" "$(eval_raw systemd.defaultUnit)" "default target"
assert_eq "true" "$(eval_bool 'systemd.services."getty@tty1".enable')" "tty1 getty enabled"

echo "[3/4] garantir independencia de mounts de sessao"
assert_eq "false" "$(eval_bool security.pam.mount.enable)" "pam_mount disabled"

echo "[4/4] garantir toolkit de troubleshooting"
packages_json="$("${nix_cmd[@]}" eval --json "$rescue_cfg.environment.systemPackages" --apply 'pkgs: builtins.map (p: p.name) pkgs')"
assert_contains "$packages_json" "\"ethtool" "ethtool package"
assert_contains "$packages_json" "\"tcpdump" "tcpdump package"
assert_contains "$packages_json" "\"strace" "strace package"
assert_contains "$packages_json" "\"tmux" "tmux package"
assert_contains "$packages_json" "\"nfs-utils" "nfs-utils package"

echo "Rescue-minimal smoke harness passed."