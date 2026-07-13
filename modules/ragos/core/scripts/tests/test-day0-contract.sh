#!/usr/bin/env bash
# Purpose: Consolidar o contrato Day-0 entre instalador, first publish e primeiro ciclo operacional
# Category: tests
# Safety: safe
# Expected environment: checkout do RAGOS com Nix flakes habilitados
# Requires: bash, nix, grep

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  grep -Fq "$needle" <<<"$haystack" || {
    echo "ASSERT FAIL [$label]: missing '$needle'" >&2
    exit 1
  }
}

echo "[1/8] canonical docs describe Day-0 honestly"
day0_doc="$(cat "$repo_root/docs/day0-acceptance.md")"
runbook_doc="$(cat "$repo_root/docs/runbook.md")"
installer_doc="$(cat "$repo_root/installer/README.md")"
scripts_doc="$(cat "$repo_root/scripts/README.md")"
docs_index="$(cat "$repo_root/docs/README.md")"
dev_doc="$(cat "$repo_root/docs/dev.md")"

assert_contains "$day0_doc" "Deve funcionar logo apos reinstalar" "day0 must work heading"
assert_contains "$day0_doc" "Ainda exige esforco demais hoje" "day0 friction heading"
assert_contains "$day0_doc" "Bloqueios de release" "day0 release blockers"
assert_contains "$day0_doc" "scripts/lab/validate-srv-rag-libvirt.sh" "day0 destructive harness reference"
assert_contains "$day0_doc" "ragc doctor" "day0 doctor contract"
assert_contains "$day0_doc" "/home/<usuario>" "day0 nfs home contract"
assert_contains "$runbook_doc" "day0-acceptance.md" "runbook links day0"
assert_contains "$installer_doc" "../docs/day0-acceptance.md" "installer links day0"
assert_contains "$scripts_doc" "test-day0-contract.sh" "scripts index day0 test"
assert_contains "$scripts_doc" "validate-srv-rag-libvirt.sh" "scripts index day0 harness"
assert_contains "$docs_index" "day0-acceptance.md" "docs index day0"
assert_contains "$dev_doc" "test-day0-contract.sh" "dev guide day0 validation"

echo "[2/8] destructive harness entrypoint exists"
[[ -f "$repo_root/scripts/lab/validate-srv-rag-libvirt.sh" ]] || {
  echo "ASSERT FAIL [day0 harness]: missing scripts/lab/validate-srv-rag-libvirt.sh" >&2
  exit 1
}

echo "[3/8] installer live-media contract"
bash "$repo_root/scripts/tests/test-installer-live-media-contract.sh"

echo "[4/8] installer first-publish contract"
bash "$repo_root/scripts/tests/test-installer-first-publish-contract.sh"

echo "[5/8] inventory contracts"
bash "$repo_root/scripts/tests/test-client-inventory-routing.sh"
bash "$repo_root/scripts/tests/test-clients-inventory-validation.sh"

echo "[6/8] ragc contracts"
bash "$repo_root/scripts/tests/test-ragc-phaseA.sh"
bash "$repo_root/scripts/tests/test-ragc-channels.sh"

echo "[7/8] runtime guardrails"
bash "$repo_root/scripts/tests/test-runtime-guardrails.sh"

echo "[8/8] release blockers are explicit in canonical doc"
assert_contains "$day0_doc" "o primeiro publish falha ou exige editar estado fora do contrato documentado" "day0 publish blocker"
assert_contains "$day0_doc" "o cliente nao chega em SDDM ou nao consegue abrir sessao" "day0 client login blocker"
assert_contains "$day0_doc" "o contrato Day-0 nao tem harness reproduzivel" "day0 harness blocker"

echo "Day-0 contract harness passed."
