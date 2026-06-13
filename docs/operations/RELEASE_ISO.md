# Release ISO no GitHub

Procedimento canônico para publicar uma ISO oficial do Kryonix como
GitHub Release. Sempre executado a partir do DEV-MOTOR
(`/home/rocha/kryonix/kryonix`), nunca de `/etc/kryonix`.

Skill: [`.claude/skills/git-dev-prod/SKILL.md`](../../.claude/skills/git-dev-prod/SKILL.md).

## 1. Pré-requisitos

- Estar em `/home/rocha/kryonix/kryonix` (DEV-MOTOR).
- Repo limpo: `git status --short` vazio.
- `main` em fast-forward com `origin/main`.
- `nix flake check --keep-going` passando.
- `gh` autenticado: `gh auth status` em verde.
- Notas de versão preparadas: `docs/releases/v<X.Y.Z>.md`.

Se qualquer item falhar, **abortar** e reportar. Não tentar resolver
auth `gh` automaticamente.

## 2. Versão

Versão segue SemVer + roadmap em `docs/ROADMAP.md`. Sempre prefixar com
`v` (ex.: `v0.1.0`). Tags são **anotadas**, nunca leves.

## 3. Procedimento

```bash
cd /home/rocha/kryonix/kryonix

# 1. higiene de estado
git status --short
git fetch --all --prune --tags
git pull --ff-only origin main

# 2. build da ISO (modo online é o default)
kryonix iso
# alternativa direta (sem CLI):
# nix build --arg offlineMode false -f iso.nix

# verificar saída
find result/iso -name '*.iso' -maxdepth 2
du -sh result/iso/*.iso

# 3. checksum reprodutível
( cd result/iso && sha256sum *.iso ) > SHA256SUMS
cat SHA256SUMS

# 4. preparar notas
test -f docs/releases/v0.1.0.md || $EDITOR docs/releases/v0.1.0.md
git add docs/releases/v0.1.0.md
git commit -m "docs(release): notas v0.1.0"
git push origin main

# 5. tag anotada
git tag -a v0.1.0 -m "Kryonix OS v0.1.0"
git push origin v0.1.0

# 6. release no GitHub
gh auth status
gh release create v0.1.0 \
  result/iso/*.iso \
  SHA256SUMS \
  --title "Kryonix OS v0.1.0" \
  --notes-file docs/releases/v0.1.0.md
```

## 4. O que **não** fazer

- Commitar o arquivo `.iso` no Git. Ele só vai como asset de release.
- Tag leve (`git tag v0.1.0` sem `-a/-m`).
- Force-push da tag.
- Usar tag já existente sem comunicar (renomear ou recriar tag).
- Subir release a partir de `/etc/kryonix`.

## 5. Modelo de nota de versão

Arquivo `docs/releases/v<X.Y.Z>.md`:

```markdown
# Kryonix OS v0.1.0

## Destaques
- ...

## Mudanças incluídas
- ...

## Hosts validados
- inspiron: PASS / WARN / FAIL (com evidência)
- glacier: PASS / WARN / FAIL (com evidência)

## ISO
- Arquivo: kryonix-os-v0.1.0-x86_64.iso
- SHA256: <sha>
- Modo: online (default) | offline

## Como instalar
Ver `docs/INSTALL.md`.

## Rollback
Ver `docs/operations/ROLLBACK_TAGS.md`.
```

## 6. Validações pós-release

```bash
gh release view v0.1.0
gh release download v0.1.0 -p '*.iso' -p 'SHA256SUMS' -D /tmp/kryonix-release-check
( cd /tmp/kryonix-release-check && sha256sum -c SHA256SUMS )
```

Se o checksum falhar no download, **revogar** o release (ou trocar
asset). Nunca deixar release publicado com asset corrompido.

## 7. Estado atual da CLI

`kryonix iso` já existe (`packages/kryonix-cli/main.sh`, comando `iso`).
Já mostra modo (`online/offline`) e tamanho final.

Pendência declarada (não escopo desta entrega):

```bash
kryonix release iso --version v0.1.0
```

Esse comando deve empacotar §3 inteiro (build + sha + tag + `gh release
create`), com gates de segurança equivalentes a esta página. Implementar
em PR separado, com testes shell e mocks de `gh`.

## 8. Boa prática operacional

- Toda release tem PR de notas em `docs/releases/` mergeado antes da tag.
- A tag aponta exatamente para o commit cuja flake produziu a ISO.
- Reproduzir o checksum a partir do código-fonte deve dar o mesmo
  `sha256` da ISO publicada. Se não der, abrir investigação.
