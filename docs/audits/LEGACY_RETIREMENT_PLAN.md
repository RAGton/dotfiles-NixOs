# Kryonix — Plano de Aposentadoria do Legado

Status atual: **PARTIAL / READY_FOR_REVIEW**

Este plano não remove código. Ele define como distinguir compatibilidade ainda
usada de legado de instalação que pode ser aposentado com segurança.

## Inventário de legado confirmado

| Sinal | Local | Classificação | Ação nesta fase |
|---|---|---|---|
| Schema v1 | `kryxd/ui/src/install-plan.schema.json` | legado de instalação ainda importado pela UI | manter; substituir somente após parity v2 |
| `INSTALL_PLAN_VERSION = 1` | `kryxd/ui/src/utils/installPlan.js` | marcador inconsistente com payload v2 | manter até patch de contrato acompanhado de testes |
| `disk.mode` e `disk.*` | UI, testes e docs do engine | vocabulário v1 | manter como compatibilidade documentada; não usar em novo contrato |
| `source/profile/network/admin` | schema/UI v1 | envelope v1 | mapear para v2 ou remover do fluxo ativo após migração |
| `/api/v1/*` | Dashboard e API operacional | compatibilidade operacional ativa | **não remover** |
| `/api/v1/legacy/*` | `kryxd/src/main.rs` | rotas antigas montadas sob namespace de compatibilidade | medir consumidores; manter respostas explícitas de desativação quando aplicável |
| `/disk/apply`, `/api/partition`, `/install/finalize` | `kryxd/src/main.rs` | endpoints destrutivos antigos | já retornam `LEGACY_ROUTE_DISABLED`; manter até remoção após evidência |
| `FEATURE_CATALOG` sem backend registry | `kryxd/ui/src/data/featureCatalog.js` | duplicação de capability | migrar para registry compartilhado |
| documentação v1 | `kryonix/docs/installer/INSTALL_PLAN.md` | documentação desatualizada | sincronizar depois do contrato v2 |

## Regras de aposentadoria

1. Não remover uma rota ou campo apenas porque contém `legacy`, `v1` ou
   `deprecated`.
2. Classificar cada consumidor por origem: UI ativa, teste, documentação,
   compatibilidade externa ou código morto.
3. Preferir primeiro uma resposta explícita de incompatibilidade (`410` ou erro
   de contrato) e observabilidade, depois remover.
4. Não aceitar v1 implicitamente no deserializador v2.
5. Não misturar a migração do schema com habilitação de topologias destrutivas.
6. Manter rollback: a UI deve conseguir voltar ao commit anterior sem deixar
   um backend que aceite uma forma ambígua do plano.

## Fases propostas

### Fase L0 — documentação e medição

- publicar a matriz `REPOSITORY_TRUTH_MATRIX.md`;
- gerar inventário em CI;
- marcar o schema v1 como `legacy-install-plan-v1`;
- adicionar contagem/telemetria de consumidores do envelope antigo sem registrar
  segredos ou payloads;
- atualizar docs para distinguir API operacional v1 de Installer v2.

Saída: nenhum comportamento de runtime alterado.

### Fase L1 — contrato v2 único

- fazer a UI importar o schema v2 por caminho gerado ou dependência explícita;
- ajustar `buildInstallPlanPayload` para produzir exatamente
  `InstallPlanV2`;
- mover campos puramente de UI para estado transitório, fora do payload;
- adicionar teste de contrato UI → desserialização Rust;
- documentar a transformação de features para os buckets v2.

Gate: testes UI e Rust passam; um fixture v2 válido é aceito e um fixture v1 é
rejeitado pelo backend.

### Fase L2 — registry de capabilities

- definir registry versionado no crate `kryx`;
- gerar projeção JS para a UI;
- derivar `requires`, `conflicts`, status e bloqueios do mesmo contrato;
- substituir rejeições dispersas por validação baseada no registry;
- manter `manual`, `raid` e `luks2` como `unsupported` até haver executor e
  validação de segurança reais.

Gate: não existe capability `ready` na UI que o backend rejeite por uma regra
não representada no registry.

### Fase L3 — desativação observável

- retirar consumidores do schema v1;
- marcar rotas de instalação antigas como removíveis;
- manter `410` por uma janela de compatibilidade documentada;
- remover código morto em commit isolado, com teste de ausência de rota;
- atualizar changelog e rollback.

Gate: busca de consumidores retorna zero fora de arquivo histórico/fixture
explicitamente classificado.

## Fora do escopo desta fase

- apagar arquivos;
- alterar `/etc/kryonix`;
- habilitar RAID, manual ou LUKS2;
- executar `nixos-rebuild switch`, `disko`, `mkfs.*`, reboot ou instalação real;
- publicar conhecimento no Vault.
