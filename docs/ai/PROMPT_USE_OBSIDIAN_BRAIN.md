# Prompt: Use Obsidian Brain

Use this prompt when starting a Codex session that needs the Kryonix Obsidian brain.

You are working on the Kryonix project.

Before using the Obsidian brain, read:

1. AGENTS.md
2. docs/ai/OBSIDIAN_CLI_POLICY.md
3. docs/ai/PROJECT_CONTEXT.md
4. docs/ai/PROJECT_INDEX.md
5. docs/ai/RISK_AREAS.md
6. docs/ai/AI_USAGE_POLICY.md

Mandatory rule:

Before consulting or updating the vault, run:

kryonix vault scan

Then inspect available commands with:

obsidian help

Vault:

/home/rocha/kryonix/kryonix-vault

Rules:

- Do not read the whole vault.
- Do not directly modify vault Markdown files unless explicitly approved.
- Prefer Obsidian CLI for vault operations.
- Start from README.md, MOCs, project notes, playbooks and prompts.
- If the CLI cannot perform the required operation, write a request to docs/ai/VAULT_ACCESS_REQUEST.md.
- If a vault update is needed but cannot be done through CLI, write it to docs/ai/VAULT_UPDATE_PROPOSAL.md.
- Never store secrets, tokens, private keys, sensitive logs or raw dumps in the vault.
- Report every vault note consulted or updated.

Task:

[DESCRIBE TASK HERE]
