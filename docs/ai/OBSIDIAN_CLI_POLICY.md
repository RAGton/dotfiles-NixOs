# Obsidian CLI Policy

## Objective

The Obsidian vault is the technical brain for this project.

Vault path:

/home/rocha/kryonix/kryonix-vault

This project requires agents to use Obsidian CLI as the official access gate for the vault.

## Mandatory check

Before consulting, opening, searching, updating, creating, renaming or deleting anything in the vault, the agent must run:

kryonix vault scan

If the check fails, stop immediately.

The agent must not continue with direct filesystem access unless explicitly approved by the user.

## Required flow

Before using the brain:

1. Read AGENTS.md.
2. Read docs/ai/OBSIDIAN_CLI_POLICY.md.
3. Run kryonix vault scan.
4. Run obsidian help to inspect available CLI commands.
5. Use Obsidian CLI whenever the needed operation is supported.
6. If Obsidian CLI does not support the needed operation, create a proposal in docs/ai/VAULT_ACCESS_REQUEST.md instead of directly accessing the vault.

## Reading policy

The agent must not read the entire vault.

Start with:

1. README.md
2. 01-MOCs/
3. 03-Projetos/Kryonix.md
4. 06-Playbooks/
5. 07-Prompts/
6. 08-Referencias/

Only read notes relevant to the current task.

## Writing policy

The agent must not directly create, rename, move, delete or bulk-edit vault Markdown files by raw filesystem operations.

When vault updates are needed:

1. prefer Obsidian CLI
2. if Obsidian CLI supports the operation, use it
3. if not supported, write the intended change to docs/ai/VAULT_UPDATE_PROPOSAL.md
4. wait for explicit user approval before direct filesystem modification

## Forbidden

The agent must not:

- read the whole vault
- scan the whole vault recursively without a narrow reason
- copy raw PDFs, HTML dumps or large documents into context
- store secrets, tokens, private keys, passwords, SSH keys, API keys, client data or sensitive logs
- treat forums or random repository code as architectural truth
- overwrite vault notes without explaining the diff
- modify the vault without reporting what changed

## Approved exception protocol

Direct filesystem access to the vault is allowed only when all conditions are true:

1. Obsidian CLI is available and was checked
2. the CLI cannot perform the needed operation
3. the agent explains the limitation
4. the agent writes the request to docs/ai/VAULT_ACCESS_REQUEST.md
5. the user explicitly approves direct access

## Required report after vault use

After using the vault, the agent must report:

1. CLI check result
2. Obsidian commands used
3. notes consulted
4. notes created or updated
5. reason for each update
6. risk of the change
7. whether links may need review
8. git diff if the vault is versioned

## Mandatory vault targeting

All Obsidian CLI commands that access the brain must explicitly target the Kryonix vault:

```sh
vault=kryonix-vault
