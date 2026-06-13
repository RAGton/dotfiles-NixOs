# Kryonix — Fluxo Git DEV/PROD

Documento operacional. Define como dev, sync e produção convivem nos
repositórios `kryonix` (motor) e `kryonixos` (downstream/site/ISO).

Skill correspondente: [`.claude/skills/git-dev-prod/SKILL.md`](../../.claude/skills/git-dev-prod/SKILL.md).

## 1. Por que separar DEV e PROD

Desenvolver direto em `/etc/kryonix` confunde estado vivo do sistema com
trabalho em curso e abre porta para:

- boot quebrado por commit em andamento;
- `flake.lock` mexido sem validação;
- secret vazando pelo `git status` errado;
- rollback obscuro porque a árvore que rodou nunca foi a árvore que veio
  do GitHub.

Separar resolve com uma regra única: **só `/home/rocha/kryonix/*` é
área de edição; `/etc/*` só consome o que já está versionado no GitHub.**

## 2. Layout canônico

```txt
/home/rocha/kryonix/             # DEV
├── kryonix/                     # motor (este repo)
└── kryonixos/                   # downstream / site / docs públicos / release

/etc/kryonix/                    # PROD motor (apontado pelo nixos-rebuild)
/etc/kryonixos/                  # PROD downstream
```

Repos remotos:

- `git@github.com:RAGton/kryonix.git`
- `git@github.com:RAGton/kryonixos.git`

## 3. Bootstrap

### 3.1 DEV (HOME)

```bash
mkdir -p /home/rocha/kryonix
git clone git@github.com:RAGton/kryonix.git    /home/rocha/kryonix/kryonix
git clone git@github.com:RAGton/kryonixos.git  /home/rocha/kryonix/kryonixos
```

### 3.2 PROD (`/etc/*`)

Só se ainda **não existir**:

```bash
sudo git clone git@github.com:RAGton/kryonix.git    /etc/kryonix
sudo git clone git@github.com:RAGton/kryonixos.git  /etc/kryonixos
```

Se já existe, **auditar antes de mexer** — pode ser uma cópia legada
com alterações locais não versionadas:

```bash
cd /etc/kryonix
git status --short
git remote -v
git branch --show-current
git log --oneline --decorate -5
```

Divergências → pendência humana. Nunca `git reset --hard` aqui.

## 4. Detecção de ambiente

Snippet usado pela skill e pelos scripts:

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

Matriz de permissões:

| Ambiente   | Editar | Commit | `nix flake update` | `git push` | `kryonix switch` |
|------------|:------:|:------:|:------------------:|:----------:|:----------------:|
| DEV-MOTOR  | ✅     | ✅     | ✅                 | ✅         | ❌               |
| DEV-SITE   | ✅     | ✅     | n/a                | ✅         | ❌               |
| PROD-MOTOR | ❌     | ❌     | ❌                 | ❌         | ✅ (pós-check)   |
| PROD-SITE  | ❌     | ❌     | n/a                | ❌         | n/a              |

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

# commit explícito e pequeno
git add <arquivos>                   # nunca `git add .`
git diff --cached --stat
git commit -m "tipo(escopo): resumo curto"
git push origin <branch>
```

PR no GitHub. Merge para `main` exige check verde.

## 6. Loop PROD

```bash
cd /etc/kryonix                      # ou /etc/kryonixos
sudo git fetch --all --prune --tags
sudo git status --short              # tem que estar limpo
sudo git pull --ff-only origin main  # se falhar, parar

kryonix check
kryonix diff
kryonix test                         # ativação não-persistente
# depois, conforme risco:
kryonix boot
kryonix switch
```

Falha de `--ff-only` em PROD significa divergência local ou history
rewrite. Nenhum dos dois deve ser resolvido por automação — abrir
ticket, decidir humano.

## 7. O que **nunca** acontece

- Editor de código aberto em `/etc/kryonix*`.
- `nix flake update` em PROD.
- `git push` a partir de `/etc/*`.
- `git add .` em qualquer lugar.
- `git reset --hard` sem aprovação explícita.
- `git push --force` em `main`.
- Commit contendo ISO, `.env`, chaves, tokens, `flake.lock` órfão.

## 8. Mapeamento com a CLI atual

A CLI já cobre boa parte do ciclo:

| Intenção                | Comando atual                | Observação                                       |
|-------------------------|------------------------------|--------------------------------------------------|
| Status                  | `kryonix git-status`         | Olha `$KRYONIX_SYSTEM_REPO` (default `/etc/kryonix`) |
| Pull                    | `kryonix pull`               | Usa `git pull --rebase` (não `--ff-only`)        |
| Deploy                  | `kryonix deploy`             | `nix flake check` + `nh os switch`               |
| Pull + Deploy           | `kryonix sync`               | Conveniente para PROD pós-merge                  |
| Update                  | `kryonix update`             | Roda `nix flake update` (sem DEV/PROD split)     |
| ISO                     | `kryonix iso`                | Build em `result/iso/`                           |

Pendências (registrar como tickets, não aplicar de afogadilho):

- `kryonix env status` — expor ambiente detectado.
- `kryonix git sync-dev` / `sync-prod` — wrappers DEV/PROD-aware com
  `--ff-only` em PROD.
- `kryonix update` — split DEV vs PROD (ver `KRYONIX_UPDATE_POLICY.md`).
- `kryonix release iso --version vX.Y.Z` — automatiza §5 de
  `RELEASE_ISO.md`.
- `kryonix rollback tag vX.Y.Z` — empacota o fluxo de
  `ROLLBACK_TAGS.md`.

Pontos de patch identificados:

- `packages/kryonix-cli/git.sh:83` `kryonix_pull_repo` — `--rebase`
  → `--ff-only` em PROD.
- `packages/kryonix-cli/nixos.sh:416` `update_flake_lock` — abortar
  em PROD.
- `packages/kryonix-cli/registry.sh` — registrar novos comandos.

## 9. Higiene esperada por entrega

Antes de cada push (DEV):

```bash
nix fmt
nix flake show --all-systems
nix flake check --keep-going
bash -n packages/kryonix-cli/*.sh
git diff --check
```

Antes de cada `switch` (PROD):

```bash
kryonix check
kryonix diff
kryonix test
```

Falhas reais → pendência declarada no relatório. Nunca silenciar.
