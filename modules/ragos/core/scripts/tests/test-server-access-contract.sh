
#!/usr/bin/env bash
# Purpose: Validar o contrato de acesso do srv-rag via SSH e consoles locais/seriais
# Category: tests
# Safety: safe
# Expected environment: checkout do RAGOS com Nix flakes
# Requires: nix, python3

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
nix_cmd=(nix --extra-experimental-features "nix-command flakes")

tmp_runtime="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_runtime"
}
trap cleanup EXIT

cp "$repo_root/server/runtime/params.example.nix" "$tmp_runtime/params.nix"
cp "$repo_root/server/runtime/hardware-configuration.example.nix" "$tmp_runtime/hardware-configuration.nix"
sed -i 's/runtimeSource = "example";/runtimeSource = "runtime";/' "$tmp_runtime/params.nix"

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  grep -Fq "$needle" <<<"$haystack" || {
    echo "ASSERT FAIL [$label]: missing '$needle'" >&2
    exit 1
  }
}

server_expr="$(cat <<EOF
let
  flake = builtins.getFlake "path:$repo_root";
  cfg = flake.nixosConfigurations.srv-rag.config;
  serviceEnabled = name:
    if builtins.hasAttr name cfg.systemd.services then
      ((builtins.getAttr name cfg.systemd.services).enable or false)
    else
      false;
in
builtins.toJSON {
  hostName = cfg.networking.hostName;
  openssh = cfg.services.openssh.enable or false;
  firewallTcp = cfg.networking.firewall.allowedTCPPorts or [ ];
  kernelParams = cfg.boot.kernelParams or [ ];
  gettyTty1 = serviceEnabled "getty@tty1";
  serialGettyTtyS0 = serviceEnabled "serial-getty@ttyS0";
  serialGettyHvc0 = serviceEnabled "serial-getty@hvc0";
  serialGettyTtyAMA0 = serviceEnabled "serial-getty@ttyAMA0";
  shellInit = cfg.programs.bash.interactiveShellInit or "";
  loginPam = cfg.security.pam.services.login.text or "";
  sddmPam = cfg.security.pam.services.sddm.text or "";
}
EOF
)"

echo "[1/4] avaliar srv-rag com runtime temporario controlado para validar contrato de acesso"
server_json="$(
  RAGOS_RUNTIME_ROOT="$tmp_runtime" \
  RAGOS_ALLOW_PLACEHOLDER_RUNTIME=1 \
  RAGOS_ENFORCE_RUNTIME_GUARDS=0 \
  "${nix_cmd[@]}" eval --impure --raw --expr "$server_expr" \
    | python3 -c 'import json,sys; print(json.dumps(json.loads(sys.stdin.read()), separators=(",", ":")))'
)"

echo "[2/4] SSH continua como caminho primario"
assert_contains "$server_json" '"hostName":"srv-rag"' "host name"
assert_contains "$server_json" '"openssh":true' "openssh enabled"
assert_contains "$server_json" '"firewallTcp":[22]' "ssh firewall"

echo "[3/4] fallback local e serial ficam explicitamente habilitados"
assert_contains "$server_json" '"gettyTty1":true' "tty1 getty"
assert_contains "$server_json" '"serialGettyTtyS0":true' "ttyS0 serial getty"
assert_contains "$server_json" '"serialGettyHvc0":true' "hvc0 serial getty"
assert_contains "$server_json" '"serialGettyTtyAMA0":true' "ttyAMA0 serial getty"
assert_contains "$server_json" '"console=ttyS0,115200n8"' "ttyS0 kernel console"
assert_contains "$server_json" '"console=hvc0"' "hvc0 kernel console"
assert_contains "$server_json" '"console=ttyAMA0,115200n8"' "ttyAMA0 kernel console"
assert_contains "$server_json" '"console=tty1"' "tty1 kernel console"

echo "[4/4] welcome local aceita tty1 e familias seriais suportadas"
assert_contains "$server_json" '/dev/tty1|/dev/ttyS*|/dev/hvc*|/dev/ttyAMA*' "welcome tty pattern"
assert_contains "$server_json" '"loginPam":"' "login pam rendered"
assert_contains "$server_json" 'pam_unix.so' "pam unix preserved"
assert_contains "$server_json" 'pam_exec.so' "pam audit hook uses pam_exec"

if grep -Fq 'bin/bash -c' <<<"$server_json"; then
  echo "ASSERT FAIL [pam text override]: login/sddm PAM still references bash as module" >&2
  exit 1
fi

echo "Server access contract harness passed."
