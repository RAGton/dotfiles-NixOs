---
name: git-dev-prod
description: Kryonix Git Dev/Prod Workflow — separa desenvolvimento no HOME (/home/rocha/kryonix/*) de produção em /etc/kryonix e /etc/kryonixos, padroniza sync, release ISO, rollback e o contrato de `kryonix update` (DEV vs PROD). Use sempre que o agente for tocar git, flake.lock, ISO, release, tag ou rollback no projeto Kryonix.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
---

# Skill: Kryonix Git Dev/Prod Workflow

Padroniza o fluxo profissional de desenvolvimento e produção do Kryonix.
Vale para Aura, Claude Code, Codex, Cursor ou qualquer outro agente operando
nos repositórios `kryonix` (motor) e `kryonixos` (downstream / site / ISO).

A constituição curta do projeto está em `AGENTS.md`. Esta skill é a operacional.

> **Duas cópias, papéis distintos:**
>
> - `.claude/skills/git-dev-prod/SKILL.md` (este arquivo) — skill carregada
>   por Claude Code / Aura, com `allowed-tools` para o agente.
> - [`skills/git-dev-prod/SKILL.md`](../../../skills/git-dev-prod/SKILL.md)
>   — skill **canônica do repositório**, fonte de verdade para humanos e
>   qualquer outro agente (Codex, Cursor, scripts CI, etc.).
>
> Ao atualizar uma, propagar para a outra no mesmo commit.

---

## 1. Mapa de ambientes

```txt
/home/rocha/kryonix/             = DEV (única área normal de alteração)
├── kryonix/                     = repo motor (este repositório)
└── kryonixos/                   = repo downstream/site/docs/ISO/release

/etc/kryonix/                    = PROD (motor instalado)
/etc/kryonixos/                  = PROD (downstream instalado)
```

Regra dura: **nunca desenvolver direto em `/etc/*`**. PROD só consome commits
e tags aprovadas, via `git pull --ff-only`.

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

Leia (sem alterar) o contexto canônico antes de mexer em código ou docs:

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

Se algum arquivo não existir, registre como pendência real no relatório
final. Nunca invente estado.

---

## 3. Detecção de ambiente

A skill detecta em qual repo está antes de propor qualquer comando:

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

Comportamento por ambiente:

| Ambiente   | Edições | `nix flake update` | `git push` | `kryonix switch` |
|------------|---------|--------------------|------------|------------------|
| DEV-MOTOR  | sim     | sim                | sim        | não              |
| DEV-SITE   | sim     | n/a                | sim        | não              |
| PROD-MOTOR | **não** | **não**            | **não**    | depois de validar |
| PROD-SITE  | **não** | **não**            | **não**    | n/a              |
| UNKNOWN    | abortar | abortar            | abortar    | abortar          |

Se o `PWD` for `UNKNOWN`, peça ao usuário para confirmar o repo correto.

Em hosts ainda não migrados, `/etc/kryonix` pode ser a única cópia. Nesse
caso, a skill **avisa** o usuário a clonar para o HOME antes de continuar
qualquer alteração; ela não duplica nem migra repo automaticamente.

---

## 4. Bootstrap (uma vez por máquina)

DEV (HOME) — único lugar onde se desenvolve:

```bash
mkdir -p /home/rocha/kryonix
git clone git@github.com:RAGton/kryonix.git    /home/rocha/kryonix/kryonix
git clone git@github.com:RAGton/kryonixos.git  /home/rocha/kryonix/kryonixos
```

PROD (`/etc/*`) — só se ainda **não existir**:

```bash
sudo git clone git@github.com:RAGton/kryonix.git    /etc/kryonix
sudo git clone git@github.com:RAGton/kryonixos.git  /etc/kryonixos
```

Se `/etc/kryonix` já existir, **não sobrescrever**. Auditar primeiro:

```bash
cd /etc/kryonix
git status --short
git remote -v
git branch --show-current
git log --oneline --decorate -5
```

Reportar divergências como pendência. Não fazer `git reset --hard`, não
fazer `git clean -fdx`, não fazer force checkout.

---

## 5. Fluxo Git diário (DEV)

```bash
cd /home/rocha/kryonix/kryonix     # ou kryonixos

git status --short
git fetch --all --prune --tags
git pull --ff-only                  # nunca --rebase silencioso, nunca merge

# trabalhar...

nix fmt                             # ou: kryonix fmt
nix flake check --keep-going        # ou: kryonix check
# se mexer em host: kryonix test --host <h>

git add <arquivos explícitos>       # NUNCA `git add .`
git diff --cached --stat
git commit -m "<tipo>(<escopo>): <resumo curto>"
git push origin <branch>
```

Após push, abrir PR no GitHub. Merge para `main` apenas com check verde.

---

## 6. Fluxo Git produção (PROD)

PROD recebe somente o que já está em `main` (ou em tag aprovada):

```bash
cd /etc/kryonix
sudo git fetch --all --prune --tags
sudo git status --short             # tem que estar limpo
sudo git pull --ff-only origin main

kryonix check                       # nix flake check
kryonix diff                        # delta vs current-system
kryonix test                        # ativação não-persistente
# só então, conforme risco:
kryonix boot                        # commit para o próximo boot
kryonix switch                      # ativação imediata
```

Regras duras em PROD:

- Nenhum editor é aberto em `/etc/kryonix*` para mudar código fonte.
- `nix flake update` **não roda em PROD**. `flake.lock` em PROD é
  resultado de um pull, nunca de uma escrita local.
- Se `git pull --ff-only` falhar (não fast-forward), parar. Reportar e
  pedir decisão humana — pode ser merge perigoso ou history rewrite.

---

## 7. Contrato de `kryonix update`

Resumo executável. Detalhes em `docs/operations/KRYONIX_UPDATE_POLICY.md`.

Todo `kryonix update` deve:

1. Detectar o repo (ver §3).
2. Rodar `git fetch --all --prune --tags`.
3. Calcular `git rev-list --count HEAD..@{u}` para saber se há
   commits remotos pendentes.
4. Decidir por ambiente:

### DEV

```bash
git pull --ff-only origin "<branch atual>"
nix flake update                # ok em DEV
# se flake.lock mudou:
kryonix fmt
kryonix check
kryonix test --host <h>
git diff --stat                 # mostrar diff
# sugerir commit pequeno explícito (não commitar automaticamente)
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

Se `kryonix update` (binário instalado) ainda não distingue DEV/PROD,
isso é **pendência declarada** — a skill deve avisar no relatório final
e propor patch em `packages/kryonix-cli/nixos.sh:416`
(função `update_flake_lock`) sem aplicar de afogadilho.

---

## 8. Release ISO (no GitHub)

Build oficial sai **do HOME**, nunca de `/etc`.

```bash
cd /home/rocha/kryonix/kryonix

# 1. validar estado limpo
git status --short
git fetch --all --tags
git pull --ff-only

# 2. build da ISO (online por padrão)
kryonix iso
# ou diretamente:
# nix build --arg offlineMode false -f iso.nix

# 3. checksum reprodutível
( cd result/iso && sha256sum *.iso ) > SHA256SUMS
cat SHA256SUMS

# 4. tag anotada (versionar)
git tag -a v0.1.0 -m "Kryonix OS v0.1.0"
git push origin v0.1.0

# 5. release no GitHub via gh
gh auth status                                  # se falhar, parar
gh release create v0.1.0 \
  result/iso/*.iso \
  SHA256SUMS \
  --title "Kryonix OS v0.1.0" \
  --notes-file docs/releases/v0.1.0.md
```

Regras:

- ISO **nunca** vai para o Git normal — só como asset de release.
- Cada release tem `docs/releases/v<X.Y.Z>.md` versionado.
- Se `gh auth status` falhar, **não** tentar resolver token
  automaticamente. Reportar e devolver para o humano.
- Tag anotada (`-a`), nunca leve (`git tag v…` puro).
- Versão segue SemVer + roadmap (`docs/ROADMAP.md`).

---

## 9. Rollback

### 9.1 Rollback por geração NixOS (preferido para emergência)

```bash
sudo nixos-rebuild --rollback switch
# ou reiniciar e escolher geração anterior no bootloader
```

Não exige git. Usa quando o sistema bootou mal após `switch`.

### 9.2 Rollback por tag git (preferido para reverter código)

```bash
cd /etc/kryonix
sudo git fetch --all --tags
sudo git checkout v0.1.0          # detached HEAD na tag
kryonix check
kryonix diff
kryonix boot                       # NÃO `switch` direto
# reiniciar e validar
```

Para voltar à branch:

```bash
sudo git checkout main
sudo git pull --ff-only
```

Proibido:

- `git reset --hard` sem aprovação explícita do usuário.
- `git push --force` em qualquer branch e ainda mais em `main`.
- Aplicar `kryonix switch` direto pós-rollback sem `check` + `diff` + `test`.

Detalhes em `docs/operations/ROLLBACK_TAGS.md`.

---

## 10. Contrato de segurança (inviolável)

1. Não usar `git add .`. Sempre listar arquivos.
2. Não usar `git reset --hard` sem aprovação explícita.
3. Não usar `git push --force` (especialmente em `main`).
4. Não dar `kryonix switch` automático depois de `update`.
5. Não rodar `disko`, `mkfs`, `parted`, `wipefs`, ou qualquer comando
   destrutivo de disco.
6. Não expor secrets. Secrets vivem em `/etc/kryonix/*.env` (`0600`,
   gitignored) — nunca em `.nix`, em docs, em logs ou no nix store.
7. Não commitar ISO no repo.
8. ISO sobe como asset de GitHub Release, não como objeto Git.
9. PROD só consome commits/tags aprovados via `--ff-only`.
10. DEV no HOME é a única área normal de alteração.

Toda violação dessas regras é motivo para abortar a operação e reportar.

---

## 11. Comandos esperados na CLI

Hoje, o `kryonix` (`packages/kryonix-cli`) expõe:

- `kryonix git-status` — status do repo apontado por `$KRYONIX_SYSTEM_REPO`
  (default `/etc/kryonix`).
- `kryonix pull` — `git fetch + git pull --rebase` (não `--ff-only`).
- `kryonix deploy` — `nix flake check` + `nh os switch`.
- `kryonix sync` — `pull` seguido de `deploy`.
- `kryonix update` — `nix flake update` (sem distinguir DEV/PROD).
- `kryonix iso` — build da ISO em `result/iso/`.

Comandos desejados (ainda **não** implementados — pendência):

```bash
kryonix env status                  # mostra DEV/PROD detectado
kryonix git status                  # alias DEV/PROD-aware de git-status
kryonix git sync-dev                # fetch + pull --ff-only no HOME + validar
kryonix git sync-prod               # fetch + pull --ff-only em /etc + check/diff
kryonix update                      # split DEV vs PROD (ver §7)
kryonix release iso --version v0.1.0
kryonix rollback tag v0.1.0
```

Enquanto não existirem, a skill executa o fluxo equivalente com `git` e
`nix` direto, sempre seguindo §5 e §6. E inclui no relatório final um
ponteiro para a pendência de implementação.

Patch points sugeridos (não aplicar sem ticket):

- `packages/kryonix-cli/git.sh:83` — `kryonix_pull_repo` trocar
  `git pull --rebase` por `git pull --ff-only` em PROD.
- `packages/kryonix-cli/nixos.sh:416` — `update_flake_lock` decidir por
  ambiente (DEV roda, PROD aborta).
- `packages/kryonix-cli/registry.sh` — registrar `env`, `release`,
  `rollback`.

---

## 12. Validações obrigatórias antes de concluir

Sempre que aplicável, rodar do DEV-MOTOR:

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

Se alterar docs/skills:

```bash
rg -n "/etc/kryonix|/home/rocha/kryonix|kryonix update|release iso|rollback" \
  docs .claude/skills packages scripts
```

Falhas marcadas como pendência real no relatório, nunca silenciadas.

---

## 13. Formato do relatório final

Toda execução desta skill termina com o bloco padrão do projeto:

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

Sem isto, a tarefa não é considerada entregue.
