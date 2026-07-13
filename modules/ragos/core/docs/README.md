# Documentacao

Status: canonical
Scope: classificacao da documentacao ativa, arquivada e complementar do repositorio
Last reviewed: 2026-04-09

O RAGOS possui uma base documental em dois niveis:

- documentos-base no topo do repositorio;
- documentos de dominio e operacao dentro de `docs/`.

## Documentos-base

- `../README.md`
- `../AGENTS.md`
- `../INSTRUCT.md`
- `../INSTRUCOES.md`

Esses arquivos definem visao executiva, contrato arquitetural e direcao institucional do projeto.

## Documentacao canonica em `docs/`

- `architecture.md`
- `branding-review.md`
  Criterios objetivos e prova minima do branding real: Plymouth, SDDM e Plasma 6.
- `boot-process.md`
- `boot-semantics.md`
  Nota `proposed` para a camada compativel de `bootMethod`, `releaseTrack`, `clientProfile` e `hardwareClass`, sem substituir o contrato atual.
- `client.md`
- `day0-acceptance.md`
  Contrato operacional minimo apos reinstalacao limpa, primeiro publish e primeiro boot de cliente.
- `server.md`
- `network.md`
- `ragc-channels-explained.md`
  Nota curta sobre canal vs perfil, inventario vs publicacao e o fluxo `MAC -> by-mac -> ipxe -> current-*`.
- `storage.md`
- `runbook.md`
- `roadmap.md`
- `dev.md`

Esses arquivos descrevem a arquitetura, a operacao e a manutencao esperadas do projeto.

## Convencao de honestidade documental

Sempre diferencie:

- estado atual implementado;
- direcao oficial;
- futuro planejado.

Se houver conflito entre um documento antigo e a direcao oficial atual, a documentacao deve dizer isso explicitamente em vez de esconder o drift.

## Documentacao arquivada

Material historico, forense, experimental ou superado fica em `archive/`.

Itens relevantes hoje:

- `archive/troubleshooting.md`
- `archive/flake-architecture.md`
- `archive/refactor-plan.md`
- `archive/roadmap.md`
- `archive/calamares-improvements-plan.md`
- `archive/installer-kiosk-forensics.md`

Esses arquivos ficam preservados por rastreabilidade, mas nao devem orientar operacao atual sem checagem critica.

## Material de apoio complementar

Os itens abaixo continuam fora de `archive/` porque ainda servem como referencia complementar, mas nao substituem a documentacao canonica:

- `install-plan-schema.md`
- `installer-contract-matrix.md`
- `codex-operations.md`
  Governanca local do Codex, agentes canonicos e skills versionadas do repo.
- `../installer/README.md`
- `references.md`
- `credits-development-support.md`

Se houver conflito entre material complementar e documentacao canonica, siga a documentacao canonica.
