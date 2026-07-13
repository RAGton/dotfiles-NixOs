#!/usr/bin/env bash
# Purpose: Validar a estrutura operacional do Codex no repositorio
# Category: tests
# Safety: safe
# Expected environment: checkout do RAGOS
# Requires: bash, grep

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
skills_root="$repo_root/.agents/skills"
agents_root="$repo_root/.codex/agents"
config_file="$repo_root/.codex/config.toml"
agents_file="$repo_root/AGENTS.md"
codex_ops_doc="$repo_root/docs/codex-operations.md"
dev_doc="$repo_root/docs/dev.md"
gitignore_file="$repo_root/.gitignore"
obsolete_skills_root="$repo_root/.codex/skills"

obsolete_agents=(
  docs_auditor.toml
  explorer.toml
  implementer.toml
  reviewer.toml
  validator.toml
)

required_skills=(
  ragos-contract-audit
  ragos-docs-drift
  ragos-publish-guard
  ragos-inventory-audit
  ragos-runbook-sync
)

required_headings=(
  "## when_to_use"
  "## when_not_to_use"
  "## target_paths"
  "## reading_checklist"
  "## implementation_checklist"
  "## validation_checklist"
  "## output_format"
  "## ragos_guardrails"
)

required_agents=(
  arquitetura.toml
  documentacao.toml
  installer.toml
  branding.toml
  validacao.toml
)

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

check_file_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq "$needle" "$file" || fail "$file missing: $needle"
}

[[ -f "$agents_file" ]] || fail "missing AGENTS.md: $agents_file"
[[ -f "$config_file" ]] || fail "missing Codex config: $config_file"
[[ -d "$agents_root" ]] || fail "agents root missing: $agents_root"
[[ -d "$skills_root" ]] || fail "skills root missing: $skills_root"
[[ -f "$codex_ops_doc" ]] || fail "missing Codex operations doc: $codex_ops_doc"
[[ -f "$dev_doc" ]] || fail "missing dev doc: $dev_doc"

check_file_contains "$agents_file" "boot oficial atual: UEFI + PXE + iPXE + HTTP"
check_file_contains "$agents_file" 'inventario externo em `/etc/ragos-inventory/clients.nix`'
check_file_contains "$agents_file" ".agents/skills/*/SKILL.md"
check_file_contains "$agents_file" '`.codex/skills/` foi aposentada'
check_file_contains "$config_file" 'model = "gpt-5.4"'
check_file_contains "$codex_ops_doc" 'A unica arvore canonica para skills do projeto e `../.agents/skills/`.'
check_file_contains "$dev_doc" '`.codex/skills/` foi removida da governanca canonica'

if grep -Fq '!/.codex/skills/' "$gitignore_file"; then
  fail ".gitignore still exposes .codex/skills as versioned source"
fi

for agent in "${required_agents[@]}"; do
  agent_file="$agents_root/$agent"
  [[ -f "$agent_file" ]] || fail "missing agent file: $agent_file"
  check_file_contains "$agent_file" 'name = "'
  check_file_contains "$agent_file" 'description = "'
  check_file_contains "$agent_file" 'developer_instructions = """'
done

for obsolete_agent in "${obsolete_agents[@]}"; do
  [[ ! -e "$agents_root/$obsolete_agent" ]] || fail "obsolete agent still present: $agents_root/$obsolete_agent"
done

if [[ -d "$obsolete_skills_root" ]] && find "$obsolete_skills_root" -type f | grep -q .; then
  fail "obsolete skills tree still present: $obsolete_skills_root"
fi

for skill in "${required_skills[@]}"; do
  skill_file="$skills_root/$skill/SKILL.md"
  [[ -f "$skill_file" ]] || fail "missing skill file: $skill_file"
  if git check-ignore -q "$skill_file"; then
    fail "skill file is ignored by git: $skill_file"
  fi

  check_file_contains "$skill_file" "name: $skill"
  check_file_contains "$skill_file" "description:"

  for heading in "${required_headings[@]}"; do
    check_file_contains "$skill_file" "$heading"
  done
done

echo "PASS: codex structure follows the repo contract"
