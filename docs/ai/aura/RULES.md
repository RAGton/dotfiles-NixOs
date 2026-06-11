# Aura Rules — Regras Invioláveis

## Proibido sem autorização explícita

```bash
nixos-rebuild switch
kryonix switch
nixos-install no host
disko
parted
sgdisk
wipefs
reboot
poweroff
git add .
git commit
```

**Proibido também:** `mkfs.*` (mkfs.ext4, mkfs.btrfs, mkfs.fat, etc.)

## Proibido como correção rápida

```bash
--impure
--accept-flake-config
```

Só usar se o usuário autorizar como workaround temporário e o relatório declarar a dívida técnica.

## Antes de patch

Obrigatório:

```bash
git status --short
git diff --stat
rg -n "<termo relevante>" <arquivos>
```

## Depois de patch

Validação padrão:

```bash
git diff --check

cd packages/kryonix-installer/ui
npm test -- --passWithNoTests
npm run build

cd /etc/kryonix/packages/kryonix-installer
cargo fmt --check
cargo test --locked

cd /etc/kryonix
nix build .#kryonix-installer --no-link -L
```

## Commit

Só depois de aprovação.

Formato:

```bash
git add <arquivos específicos>
git commit -m "<tipo>(<escopo>): <mensagem>"
```
