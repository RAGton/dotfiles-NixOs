---
name: git-dev-prod
description: Kryonix Git Dev/Prod Workflow — skill canônica do repositório. Padroniza desenvolvimento no HOME, sincronização para /etc, release ISO no GitHub e rollback por tag. Aplica-se a qualquer agente ou humano operando no Kryonix.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
---

# Skill canônica: Kryonix Git Dev/Prod Workflow

> **Duas cópias, papéis distintos:**
>
> - [`.claude/skills/git-dev-prod/SKILL.md`](../../.claude/skills/git-dev-prod/SKILL.md)
>   — skill carregada por Claude Code / Aura. Mesmo conteúdo, com permissões
>   de ferramentas para o agente.
> - `skills/git-dev-prod/SKILL.md` (este arquivo) — skill **canônica do
>   projeto**, fonte de verdade para humanos e qualquer outro agente
>   (Codex, Cursor, scripts CI, etc.).
>
> Ao atualizar uma, propagar para a outra no mesmo commit.

---

Padroniza o fluxo profissional de desenvolvimento e produção do Kryonix,
nos repositórios `kryonix` (motor) e `kryonixos` (downstream/site/ISO).

Constituição curta: `AGENTS.md`. Esta skill é o lado operacional.

---

## 1. Mapa de ambientes

```txt
/home/rocha/kryonix/             = DEV (única área normal de alteração)
├── kryonix/                     = repo motor (este repositório)
└── kryonixos/                   = repo downstream/site/docs/ISO/release

/etc/kryonix/                    = PROD (motor instalado)
/etc/kryonixos/                  = PROD (downstream instalado)
```

Regra dura: **nunca desenvolver direto em `/etc/*`**. PROD só consome
commits e tags aprovados via `git pull --ff-only`.

Fluxo obrigatório:

```txt
DEV no HOME
  → validar (fmt + check + test)
  → commit pequeno explícito
  → push para GitHub
  → PROD em /etc faz `git pull --ff-only`
  → validar (check + diff)
  → test / boot / switch conforme risco
```

---

## 2. Antes de qualquer ação

Leia (sem alterar) o contexto canônico:

```txt
AGENTS.md
docs/OPERATIONS.md
docs/CLI.md
docs/USAGE.md
docs/TESTING.md
docs/SECURITY.md
docs/ARCHITECTURE.md
docs/ROADMAP.md
docs/CURRENT_STATE.md
docs/operations/GIT_DEV_PROD_WORKFLOW.md
docs/operations/KRYONIX_UPDATE_POLICY.md
docs/operations/RELEASE_ISO.md
docs/operations/ROLLBACK_TAGS.md
```

Se algum arquivo não existir, registrar como pendência real. Não inventar
estado.

---

## 3. Detecção de ambiente

```bash
detect_env() {
  case "$PWD" in
    /home/rocha/kryonix/kryonix*)    echo "DEV-MOTOR" ;;
    /home/rocha/kryonix/kryonixos*)  echo "DEV-SITE" ;;
    /etc/kryonix*)                   echo "PROD-MOTOR" ;;
    /etc/kryonixos*)                 echo "PROD-SITE" ;;
    *)                               echo "UNKNOWN" ;;
  esac
}
```

| Ambiente   | Editar | Commit | `nix flake update` | `git push` | `kryonix switch` |
|------------|:------:|:------:|:------------------:|:----------:|:----------------:|
| DEV-MOTOR  | ✅     | ✅     | ✅                 | ✅         | ❌               |
| DEV-SITE   | ✅     | ✅     | n/a                | ✅         | ❌               |
| PROD-MOTOR | ❌     | ❌     | ❌                 | ❌         | ✅ (pós-check)   |
| PROD-SITE  | ❌     | ❌     | n/a                | ❌         | n/a              |

`UNKNOWN` → abortar e pedir confirmação humana.

---

## 4. Bootstrap (uma vez por máquina)

DEV (HOME):

```bash
mkdir -p /home/rocha/kryonix
git clone git@github.com:RAGton/kryonix.git    /home/rocha/kryonix/kryonix
git clone git@github.com:RAGton/kryonixos.git  /home/rocha/kryonix/kryonixos
```

PROD (`/etc/*`), só se ainda não existir:

```bash
sudo git clone git@github.com:RAGton/kryonix.git    /etc/kryonix
sudo git clone git@github.com:RAGton/kryonixos.git  /etc/kryonixos
```

Se já existir, **auditar antes** (`git status --short`, `git remote -v`,
`git log --oneline -5`). Divergências viram pendência humana — nunca
`git reset --hard`, nunca `git clean -fdx`.

---

## 5. Loop DEV

```bash
cd /home/rocha/kryonix/kryonix       # ou kryonixos

git status --short
git fetch --all --prune --tags
git pull --ff-only

# editar, validar
nix fmt
nix flake check --keep-going
kryonix test --host <host>           # se mexer em host

git add <arquivos>                   # nunca `git add .`
git diff --cached --stat
git commit -m "tipo(escopo): resumo curto"
git push origin <branch>
```

PR no GitHub. Merge para `main` só com check verde.

---

## 6. Loop PROD

```bash
cd /etc/kryonix                      # ou /etc/kryonixos
sudo git fetch --all --prune --tags
sudo git status --short              # tem que estar limpo
sudo git pull --ff-only origin main  # se falhar, parar

kryonix check
kryonix diff
kryonix test                         # ativação não-persistente
# conforme risco:
kryonix boot
kryonix switch
```

Falha de `--ff-only` em PROD = divergência local. Não automatizar a
solução; chamar humano.

---

## 7. Contrato de `kryonix update`

Resumo. Detalhes em `docs/operations/KRYONIX_UPDATE_POLICY.md`.

`kryonix update` deve:

1. Detectar repo (`detect_env`).
2. `git fetch --all --prune --tags`.
3. Comparar com upstream (`git rev-list --count HEAD..@{u}`).
4. Agir por ambiente:

### DEV

```bash
git pull --ff-only origin <branch atual>
nix flake update                # ok em DEV
# se flake.lock mudou:
kryonix fmt
kryonix check
kryonix test --host <h>
git diff --stat
# sugerir commit pequeno (não commitar automaticamente)
```

### PROD

```bash
# NÃO rodar `nix flake update`
# NÃO escrever em flake.lock
git pull --ff-only origin main
kryonix check
kryonix diff
# avisar se há tags novas; não dar switch automático
```

Em junho/2026 o `kryonix update` real ainda roda `nix flake update`
sem split DEV/PROD. A skill executa o equivalente seguro à mão até
que o split seja portado para
[`packages/kryonix-cli/nixos.sh`](../../packages/kryonix-cli/nixos.sh).

---

## 8. Release ISO

Ver `docs/operations/RELEASE_ISO.md`. Resumo:

```bash
cd /home/rocha/kryonix/kryonix
kryonix iso
( cd result/iso && sha256sum *.iso ) > SHA256SUMS

git tag -a v0.1.0 -m "Kryonix OS v0.1.0"
git push origin v0.1.0

gh auth status
gh release create v0.1.0 \
  result/iso/*.iso \
  SHA256SUMS \
  --title "Kryonix OS v0.1.0" \
  --notes-file docs/releases/v0.1.0.md
```

ISO **nunca** vai para o Git normal. Tag sempre anotada. `gh auth` falho
→ parar e devolver ao humano.

---

## 9. Rollback

Ver `docs/operations/ROLLBACK_TAGS.md`. Duas frentes:

### 9.1 Geração NixOS (mais rápido)

```bash
sudo nixos-rebuild --rollback switch
```

Ou bootloader, se o sistema não bootou.

### 9.2 Tag git (preferido para reverter código)

```bash
cd /etc/kryonix
sudo git fetch --all --tags
sudo git checkout v0.1.0
kryonix check
kryonix diff
kryonix boot                       # nunca `switch` direto
```

Proibido: `reset --hard`, `push --force`, recriar tag publicada,
`switch` automático pós-rollback sem `check`+`diff`+`test`.

---

## 10. Contrato de segurança (inviolável)

1. Não usar `git add .`.
2. Não usar `git reset --hard` sem aprovação explícita.
3. Não usar `git push --force` (especialmente em `main`).
4. Não dar `kryonix switch` automático após `update`.
5. Não rodar `disko`, `mkfs`, `parted`, `wipefs`.
6. Não expor secrets. Secrets ficam em `/etc/kryonix/*.env` (`0600`,
   gitignored).
7. Não commitar ISO no repo.
8. ISO sobe como asset de Release, não como objeto Git.
9. PROD só consome commits/tags via `--ff-only`.
10. DEV no HOME é a única área normal de alteração.

---

## 11. Comandos esperados na CLI

Hoje, `kryonix` (`packages/kryonix-cli`) expõe:

- `kryonix env status` — detecção DEV/PROD e matriz de permissões.
- `kryonix git-status`, `kryonix pull`, `kryonix deploy`, `kryonix sync`,
  `kryonix update`, `kryonix iso`.

`kryonix update` agora respeita DEV/PROD: em PROD não roda
`nix flake update` e usa apenas `git pull --ff-only`.

`kryonix pull` foi padronizado para `--ff-only` (não mais `--rebase`),
para evitar reescritas silenciosas em produção.

Comandos ainda **não** implementados (pendência):

```bash
kryonix git sync-dev
kryonix git sync-prod
kryonix release iso --version v0.1.0
kryonix rollback tag v0.1.0
```

Enquanto não existirem, a skill executa o equivalente com `git` + `nix`
direto, sempre seguindo §5 e §6.

---

## 12. Validações obrigatórias antes de concluir

```bash
cd /home/rocha/kryonix/kryonix
git status --short
git diff --stat
nix fmt
nix flake show --all-systems
nix flake check --keep-going
bash -n packages/kryonix-cli/*.sh
git diff --check
```

Para checagem de referências:

```bash
rg -n "/etc/kryonix|/home/rocha/kryonix|kryonix update|release iso|rollback" \
  docs .claude/skills skills packages scripts
```

Falhas → pendência declarada, nunca silenciada.

---

## 13. Relatório final

```txt
Status:
Arquivos alterados:
O que mudou:
Comandos executados:
Resultado:
Riscos:
Rollback:
Pendências:
Próximo passo recomendado:
```
