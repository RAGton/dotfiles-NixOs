#!/usr/bin/env bash
# Purpose: Validar o contrato de montagem de setores do cliente dentro da home do usuario
# Category: tests
# Safety: safe
# Expected environment: checkout do RAGOS com Nix flakes
# Requires: bash, jq, nix

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
nix_cmd=(nix --extra-experimental-features "nix-command flakes")

tmp_runtime="$(mktemp -d)"
tmp_test="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp_runtime" "$tmp_test"
}
trap cleanup EXIT

cp "$repo_root/server/runtime/params.example.nix" "$tmp_runtime/params.nix"
cp "$repo_root/server/runtime/hardware-configuration.example.nix" "$tmp_runtime/hardware-configuration.nix"
sed -i 's/runtimeSource = "example";/runtimeSource = "runtime";/' "$tmp_runtime/params.nix"

cat > "$tmp_runtime/client-users.json" <<'EOF'
{
  "rag": {
    "uid": 1000,
    "hashedPassword": "!",
    "extraGroups": ["wheel", "video", "audio", "students"],
    "groupGids": {
      "students": 3100
    }
  },
  "outsider": {
    "uid": 1002,
    "hashedPassword": "!",
    "extraGroups": ["video", "audio"],
    "groupGids": {}
  },
  "delayed": {
    "uid": 1003,
    "hashedPassword": "!",
    "extraGroups": ["video", "audio", "teachers"],
    "groupGids": {
      "teachers": 3200
    }
  }
}
EOF

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  grep -Fq "$needle" <<<"$haystack" || {
    echo "ASSERT FAIL [$label]: missing '$needle'" >&2
    exit 1
  }
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq "$needle" <<<"$haystack"; then
    echo "ASSERT FAIL [$label]: unexpected '$needle'" >&2
    exit 1
  fi
}

client_expr="$(cat <<EOF
let
  flake = builtins.getFlake "path:$repo_root";
  cfg = flake.nixosConfigurations.ragos-client-desktop-lab.config;
in
builtins.toJSON {
  studentsGid = if builtins.hasAttr "students" cfg.users.groups then cfg.users.groups.students.gid or null else null;
  teachersGid = if builtins.hasAttr "teachers" cfg.users.groups then cfg.users.groups.teachers.gid or null else null;
  ragExtraGroups = cfg.users.users.rag.extraGroups or [ ];
  outsiderExtraGroups = cfg.users.users.outsider.extraGroups or [ ];
  homeVolumes = cfg.security.pam.mount.extraVolumes or [ ];
  sddmPam = cfg.security.pam.services.sddm.text or "";
  loginPam = cfg.security.pam.services.login.text or "";
}
EOF
)"

script_build_expr="$(cat <<EOF
let
  flake = builtins.getFlake "path:$repo_root";
  cfg = flake.nixosConfigurations.ragos-client-desktop-lab.config;
  pkgMatches = builtins.filter (pkg: (pkg.name or "") == "ragos-user-sector-mounts") cfg.environment.systemPackages;
in
if pkgMatches == [ ] then
  builtins.throw "ragos-user-sector-mounts package missing from environment.systemPackages"
else
  builtins.head pkgMatches
EOF
)"

echo "[1/5] avaliar o cliente desktop-lab com runtime temporario e grupos reais"
client_json="$(
  RAGOS_RUNTIME_ROOT="$tmp_runtime" \
  RAGOS_ALLOW_PLACEHOLDER_RUNTIME=1 \
  RAGOS_ENFORCE_RUNTIME_GUARDS=0 \
  "${nix_cmd[@]}" eval --impure --raw --expr "$client_expr"
)"

students_gid="$(jq -r '.studentsGid' <<<"$client_json")"
teachers_gid="$(jq -r '.teachersGid' <<<"$client_json")"
rag_extra_groups="$(jq -cr '.ragExtraGroups' <<<"$client_json")"
outsider_extra_groups="$(jq -cr '.outsiderExtraGroups' <<<"$client_json")"
home_volumes="$(jq -cr '.homeVolumes' <<<"$client_json")"
sddm_pam="$(jq -r '.sddmPam' <<<"$client_json")"
login_pam="$(jq -r '.loginPam' <<<"$client_json")"

[[ "$students_gid" == "3100" ]] || {
  echo "ASSERT FAIL [students gid]: expected 3100, got $students_gid" >&2
  exit 1
}
[[ "$teachers_gid" == "3200" ]] || {
  echo "ASSERT FAIL [teachers gid]: expected 3200, got $teachers_gid" >&2
  exit 1
}
assert_contains "$rag_extra_groups" '"students"' "rag custom group synced"
assert_contains "$rag_extra_groups" '"wheel"' "rag wheel preserved"
assert_not_contains "$outsider_extra_groups" '"students"' "outsider must not inherit group"

echo "[2/5] PAM continua montando apenas /home via pam_mount e chama o hook de setores depois do login"
assert_contains "$home_volumes" '/srv/data/home/%(USER)' "home remote path"
assert_contains "$home_volumes" '/home/%(USER)' "home mountpoint"
assert_not_contains "$home_volumes" '/srv/data/storage' "group storage not wired into pam_mount"
assert_not_contains "$home_volumes" '/mnt/groups' "legacy mount base removed from pam_mount"
assert_contains "$sddm_pam" 'session   include       login' "sddm session still delegates to login stack"
assert_contains "$login_pam" 'ragos-user-sector-mounts' "login hook present"

echo "[3/5] realizar o hook gerado para exercitar a ordem home -> Setores -> grupos"
sector_script_pkg="$(
  RAGOS_RUNTIME_ROOT="$tmp_runtime" \
  RAGOS_ALLOW_PLACEHOLDER_RUNTIME=1 \
  RAGOS_ENFORCE_RUNTIME_GUARDS=0 \
  "${nix_cmd[@]}" build --impure --no-link --print-out-paths --expr "$script_build_expr"
)"
sector_script="$sector_script_pkg/bin/ragos-user-sector-mounts"
[[ -x "$sector_script" ]] || {
  echo "ASSERT FAIL [sector script]: executable missing at $sector_script" >&2
  exit 1
}

mkdir -p "$tmp_test/bin" "$tmp_test/home/aluno" "$tmp_test/home/outsider" "$tmp_test/home/delayed"
log_file="$tmp_test/ops.log"
mounts_file="$tmp_test/mounts.txt"
delay_marker="$tmp_test/delayed-home.ready"
touch "$log_file" "$mounts_file"
printf '%s\n' "$tmp_test/home/aluno" "$tmp_test/home/outsider" > "$mounts_file"

cat > "$tmp_test/bin/logger" <<'EOF'
#!/usr/bin/env bash
printf 'logger:%s\n' "$*" >> "$LOG_FILE"
EOF

cat > "$tmp_test/bin/getent" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "passwd" ]]; then
  case "$2" in
    aluno)
      printf 'aluno:x:1001:100:Aluno:%s/aluno:/bin/bash\n' "$TEST_HOME"
      exit 0
      ;;
    outsider)
      printf 'outsider:x:1002:100:Outsider:%s/outsider:/bin/bash\n' "$TEST_HOME"
      exit 0
      ;;
    delayed)
      printf 'delayed:x:1003:100:Delayed:%s/delayed:/bin/bash\n' "$TEST_HOME"
      exit 0
      ;;
  esac
fi
exit 2
EOF

cat > "$tmp_test/bin/id" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  -gn)
    printf 'users\n'
    ;;
  -Gn)
    case "$2" in
      aluno)
        printf 'users video audio students\n'
        ;;
      outsider)
        printf 'users video audio\n'
        ;;
      delayed)
        printf 'users video audio teachers\n'
        ;;
      *)
        exit 1
        ;;
    esac
    ;;
  *)
    exit 1
    ;;
esac
EOF

cat > "$tmp_test/bin/mountpoint" <<'EOF'
#!/usr/bin/env bash
target="${@: -1}"
if [[ "$target" == "$TEST_HOME/delayed" ]] && [[ ! -f "$DELAY_MARKER" ]]; then
  : > "$DELAY_MARKER"
  printf 'mountpoint-wait:%s\n' "$target" >> "$LOG_FILE"
  exit 1
fi
if [[ "$target" == "$TEST_HOME/delayed" ]]; then
  grep -Fxq "$target" "$MOUNTS_FILE" || printf '%s\n' "$target" >> "$MOUNTS_FILE"
fi
grep -Fxq "$target" "$MOUNTS_FILE"
EOF

cat > "$tmp_test/bin/mount" <<'EOF'
#!/usr/bin/env bash
printf 'mount:%s\n' "$*" >> "$LOG_FILE"
target="${@: -1}"
grep -Fxq "$target" "$MOUNTS_FILE" || printf '%s\n' "$target" >> "$MOUNTS_FILE"
EOF

cat > "$tmp_test/bin/umount" <<'EOF'
#!/usr/bin/env bash
target="$1"
printf 'umount:%s\n' "$*" >> "$LOG_FILE"
grep -Fxv "$target" "$MOUNTS_FILE" > "$MOUNTS_FILE.tmp"
mv "$MOUNTS_FILE.tmp" "$MOUNTS_FILE"
EOF

cat > "$tmp_test/bin/install" <<'EOF'
#!/usr/bin/env bash
printf 'install:%s\n' "$*" >> "$LOG_FILE"
target="${@: -1}"
mkdir -p "$target"
EOF

cat > "$tmp_test/bin/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

chmod +x "$tmp_test/bin/"*

PATH="$tmp_test/bin:/run/current-system/sw/bin"
export PATH LOG_FILE="$log_file" MOUNTS_FILE="$mounts_file" TEST_HOME="$tmp_test/home" DELAY_MARKER="$delay_marker"

PAM_USER=aluno PAM_TYPE=open_session "$sector_script"
assert_contains "$(cat "$log_file")" "$tmp_test/home/aluno/Setores/students" "students mounted inside home"
assert_not_contains "$(cat "$log_file")" "/mnt/groups" "legacy client path absent in hook"
[[ -d "$tmp_test/home/aluno/Setores" ]] || {
  echo "ASSERT FAIL [setores dir]: missing $tmp_test/home/aluno/Setores" >&2
  exit 1
}

before_outsider_mounts="$(grep -c '^mount:' "$log_file" || true)"
PAM_USER=outsider PAM_TYPE=open_session "$sector_script"
after_outsider_mounts="$(grep -c '^mount:' "$log_file" || true)"
[[ "$before_outsider_mounts" == "$after_outsider_mounts" ]] || {
  echo "ASSERT FAIL [outsider mount]: outsider should not receive setor mount" >&2
  exit 1
}

PAM_USER=delayed PAM_TYPE=open_session "$sector_script"
assert_contains "$(cat "$log_file")" "mountpoint-wait:$tmp_test/home/delayed" "hook waited for delayed home mount"
assert_contains "$(cat "$log_file")" "$tmp_test/home/delayed/Setores/teachers" "delayed user mounted after home"

echo "[4/5] close_session desmonta apenas o que foi criado dentro da home"
PAM_USER=aluno PAM_TYPE=close_session "$sector_script"
assert_contains "$(cat "$log_file")" "umount:$tmp_test/home/aluno/Setores/students" "students umount on logout"

echo "[5/5] nenhum arquivo ativo do contrato continua apontando clientes para /mnt/groups"
rg_output="$(rg -n '/mnt/groups' "$repo_root/client" "$repo_root/CLI_CHEAT_SHEET.md" || true)"
[[ -z "$rg_output" ]] || {
  echo "ASSERT FAIL [legacy docs/code path]: /mnt/groups still present" >&2
  echo "$rg_output" >&2
  exit 1
}

echo "Client group sector mount contract harness passed."
