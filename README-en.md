# Kryonix

Kryonix is a declarative NixOS platform for workstation, gaming, virtualization, study, and development.

- Main repository: `https://github.com/RAGton/kryonix`
- Knowledge vault: `https://github.com/RAGton/kryonix-vault.git`
- Language: [PT-BR](README.md) | English

## Daily Flow

The primary operational CLI is `kryonix`:

```sh
kryonix switch
kryonix switch --update
kryonix boot --update
kryonix home
kryonix diff
kryonix doctor
kryonix check
kryonix fmt
kryonix iso
```

## Quick Start

```sh
git clone https://github.com/RAGton/kryonix kryonix
cd kryonix
nix flake show --all-systems
nix flake check --keep-going
```

Apply the current host:

```sh
kryonix switch
```

## Operational Safety

- do not use `disko`, `format-*`, or `install-system` on the already-installed `glacier` host
- do not treat `hosts/glacier/disks.nix` as the source of truth for current hardware
- prefer `kryonix test` and `kryonix boot` before higher-risk changes
