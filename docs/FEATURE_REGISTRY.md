# Feature Registry

`modules/nixos/features/registry.nix` is the metadata source for Kryonix features.

## Purpose

The Feature Registry is a **pure metadata catalog** — it does not declare NixOS options
or activate any configuration. Each entry describes a feature with its ID, category,
risk level, dependencies, conflicts, and migration status.

The registry is intended to support future **installer/catalog export**, but the
installer must not consume it until the export contract is explicitly defined and validated.

## Architecture

```txt
schema.nix     — declares public kryonix.features.* options (no config)
registry.nix   — declares kryonix.featureRegistry metadata list (no config)
*.nix          — feature modules that declare options AND implement config
```

`schema.nix` and `registry.nix` are infrastructure, not activatable features.

## Current state

- `modules/nixos/features/` is the canonical feature tree.
- `features/` is legacy/compat during migration.
- `schema.nix` owns common namespace declarations.
- `registry.nix` must not claim runtime readiness for features that are namespace-only.
- AI runtime migration is pending and split from namespace alignment.

## Status field

Each registry entry has a `status` field indicating its migration state:

| Status | Meaning |
|---|---|
| `canonical` | Fully migrated. Options declared, config implemented, tested. |
| `partial` | Namespace declared and/or compat runtime exists, but canonical migration is incomplete. |
| `stub` | Option declared (mkEnableOption), but no config/implementation exists yet. |
| `legacy` | Deprecated compat shim. Will be removed after migration. |

Default is `canonical`. Features with other statuses should not be presented as
fully operational in the installer UI.

## AI features — current status

| Feature | Status | Detail |
|---|---|---|
| `ai.brain.client` | partial | Namespace in `schema.nix`, no runtime |
| `ai.brain.server` | partial | Namespace in `schema.nix`, no runtime |
| `ai.ollama` | partial | Compat runtime in `ai.nix` |
| `ai.neo4j` | partial | Compat runtime in `ai.nix` |
| `ai.lightrag` | stub | Option only, no implementation |
| `ai.openWebui` | stub | Option only, no implementation |
| `ai.kryonixBrain` | — | Compat shim in `ai.nix`, not in registry |

AI runtime migration must not be declared as complete in the registry until each
sub-feature has canonical implementation with proper config, validation, and
no namespace duplication with `schema.nix`.

## Installer integration — NOT YET ACTIVE

The registry exposes `config.kryonix.featureRegistry` as a list of attrsets.
This can be serialized to JSON for the installer to consume.

**However**, no export contract has been defined yet. The installer must not
read from the registry until:

1. The export format is defined and documented.
2. The registry is validated against all canonical modules.
3. A CI check ensures registry-module consistency.

## Known overlaps

- `security.firewall` (category: security) and `network.firewall.strict`
  (category: network) describe similar concepts. Future cleanup may merge them.

## Adding a new feature to the registry

1. Ensure the feature has a real `mkEnableOption` or `mkOption` in a canonical module.
2. Add a `mkFeature { ... }` entry in `registry.nix` with appropriate metadata.
3. Set `status` according to the migration state table above.
4. Set `installerVisible = false` for stubs or infrastructure features.
5. Run `nix flake check` to validate.
