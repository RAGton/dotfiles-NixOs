# Kryonix — Repository Truth Matrix

> Matriz baseada no inventário determinístico em
> `artifacts/repository-intelligence/`.
>
> Regra: código executável e contrato realmente consumido vencem documentação
> antiga. Este documento registra evidência; não substitui os schemas.

## Baseline

| Alvo | Papel | Branch | Commit | Estado observado |
|---|---|---:|---|---|
| `repos/kryonix` | motor NixOS, módulos, docs canônicas e integração do ecossistema | `main` | `123cdda738e07154099668c627894dfdd7dde322` | DEV; contém somente artefatos deliberados desta tarefa |
| `repos/kryxd` | Installer/KCP: daemon Axum, crate de domínio compartilhado e UI Vite/React | `main` | `d627aa0977124e7796f58f595059ab335ea5f5d4` | limpo no baseline |
| `/etc/kryonix` | checkout de produção/configuração | `main` | `123cdda738e07154099668c627894dfdd7dde322` | alteração preexistente em `desktop/kde/lockscreen.nix`; fora do escopo |

## Ownership e fonte autoritativa

| Área | Fonte autoritativa | Evidência | Estado |
|---|---|---|---|
| Contrato persistível do Installer | `kryxd/crates/kryx/src/domain/config.rs` | `InstallPlanV2`, `version == 2`, `deny_unknown_fields` | canônico no runtime |
| Schema público do Installer | `kryxd/schemas/install-plan.schema.json` | `$id` `install-plan-v2.schema.json`, `version.const = 2` | canônico para integração |
| Produção do payload pela UI | `kryxd/ui/src/utils/installPlan.js` | `buildInstallPlanPayload`, `rawPayload.version = 2` | implementado, mas com sinais de migração |
| Catálogo de capacidades exposto pela UI | `kryxd/ui/src/data/featureCatalog.js` | `FEATURE_CATALOG`, domínios, status, requires/conflicts | fonte atual; ainda não é registry compartilhado |
| API Installer v2 | `kryxd/src/api/mod.rs`, `kryxd/src/api/install.rs` | `/plan`, `/secrets`, `/dry-run`, `/preflight`, `/install` | canônica para instalação |
| Prefixo de montagem | `kryxd/src/main.rs` | `.nest("/api/v2", api::router())` | canônico |
| API operacional v1 | `kryxd/src/api/v1/*` e rotas legadas montadas em `/api/v1/legacy` | auth, identity, fleet, storage e compatibilidade do painel | mantida; não deve ser aposentada em bloco |
| Integração Nix | `kryonix/flake.nix` | input local `kryxd = git+file:///home/rocha/kryonix-dev/repos/kryxd` | canônica para DEV |
| Árvore gerada do target | `kryxd/src/services/target_tree.rs` | geração de arquivos para o sistema alvo | gerado em runtime; não editar como fonte |
| Documentação do plano | `kryonix/docs/installer/INSTALL_PLAN.md` | ainda descreve v1 e aponta para repo externo | desatualizada; deve ser sincronizada |

## Conflitos confirmados

### 1. Dois schemas para o mesmo fluxo

- `kryxd/schemas/install-plan.schema.json`: **v2**, envelope enxuto com
  `repository`, `storage` e `features`.
- `kryxd/ui/src/install-plan.schema.json`: **v1**, com `source`, `profile`,
  `security`, `disk`, `network`, `locale` e `admin`.
- `kryxd/ui/src/utils/installPlan.js` importa o schema v1 e declara
  `INSTALL_PLAN_VERSION = 1`, mas monta `rawPayload.version = 2`.

**Decisão:** o crate `kryx` e o schema v2 são a verdade do contrato enviado a
`POST /api/v2/plan`. A UI precisa passar a consumir uma cópia gerada ou um
schema compartilhado v2; não se deve corrigir isso alterando o backend para
aceitar silenciosamente v1.

### 2. V1 não é uma única coisa

Há duas categorias diferentes:

- **v1 operacional:** auth, identity, fleet e storage usados pelo Dashboard;
  continua ativo e tem consumidores reais na UI.
- **v1 de instalação:** `disk.mode`, `source`, `profile`, `network` e os
  endpoints de instalação antigos; parte foi desativada com `410 GONE` e parte
  ainda aparece em compatibilidade, testes ou documentação.

**Decisão:** aposentar somente o contrato de instalação v1 após a UI v2 estar
validada. Não remover `/api/v1` como prefixo geral.

### 3. Capabilities duplicadas

A UI possui `FEATURE_CATALOG`, enquanto o backend rejeita diretamente algumas
combinações em `reject_unimplemented_capabilities`:

- topologias `manual` e `raid`;
- criptografia `luks2`.

O catálogo e o backend não compartilham um registry tipado. Esta divergência é
o alvo da próxima fase, não uma autorização para habilitar capacidades.

## Critério de atualização desta matriz

Executar:

```bash
python3 scripts/knowledge/repo_inventory.py --check \
  --repo engine=/home/rocha/kryonix-dev/repos/kryonix \
  --repo kryxd=/home/rocha/kryonix-dev/repos/kryxd \
  --output artifacts/repository-intelligence
```

A matriz deve ser revisada quando mudar qualquer um destes contratos:

- schema do Install Plan;
- `InstallPlanV2`;
- `FEATURE_CATALOG` ou registry compartilhado;
- prefixos `/api/v1` e `/api/v2`;
- integração `kryxd` no flake;
- geração da árvore de target.
