# Guia de Desenvolvimento

Status: canonical
Scope: fluxo de desenvolvimento, validacao e publicacao segura
Last reviewed: 2026-04-09

## Objetivo

Este guia existe para manter o RAGOS auditavel e reproduzivel.

## Checkouts

- desenvolvimento: `~/code/ragos`
- operacional do host: `/etc/ragos`
- backup somente leitura: `~/Documents/...`

Regra:

- desenvolva em `~/code/ragos`
- promova para `/etc/ragos` apenas depois de validar
- nunca use `~/Documents/...` como workspace

## O que alterar em cada area

| Se voce quer mudar... | Area principal |
| --- | --- |
| boot, DHCP, NFS, observabilidade | `server/` |
| perfis do cliente, initrd, desktop | `client/` |
| publish, rollback, GC, manifests | `ragc/` |
| instalacao do host | `installer/` |
| branding compartilhado | `themes/` |
| documentacao operacional | `docs/` |

## Fluxo recomendado

```bash
cd ~/code/ragos
git switch main
git pull --ff-only
git submodule update --init --recursive
git switch -c fix/<escopo>-<tema>
```

## Estrutura local do Codex

- `AGENTS.md` governa as instrucoes persistentes do projeto
- `.codex/config.toml` guarda defaults locais do Codex no repo
- `.codex/agents/` contem os agentes especializados do projeto
- `.agents/skills/` e a arvore canonica versionada para skills do projeto
- `.codex/skills/` foi removida da governanca canonica e nao deve ser reintroduzida
- os agentes genericos legados (`docs_auditor`, `explorer`, `implementer`, `reviewer`, `validator`) tambem nao fazem mais parte da estrutura do repo
- skills e agentes devem assumir `~/code/ragos` como checkout oficial de desenvolvimento
- eles podem consultar `/etc/ragos` como checkout operacional para prova e comparacao, mas nunca como fonte de verdade
- eles nao devem usar `~/Documents/...`; esse path e backup somente leitura
- quando uma skill tocar promocao, ela deve distinguir claramente checkout local, checkout operacional, `lab`, `generic` e `release/tag`
- a referencia curta da estrutura fica em `docs/codex-operations.md`
- valide a estrutura com:

```bash
bash ./scripts/tests/test-codex-skills-structure.sh
```

## Validacao minima

```bash
./scripts/tests/lint-repo-organization.sh
nix --extra-experimental-features 'nix-command flakes' flake check
nix --extra-experimental-features 'nix-command flakes' eval path:$PWD#nixosConfigurations.srv-rag.config.networking.hostName
nix --extra-experimental-features 'nix-command flakes' eval path:$PWD#nixosConfigurations.ragos-client-desktop-generic.config.ragos.profile.name
nix --extra-experimental-features 'nix-command flakes' eval path:$PWD#nixosConfigurations.ragos-client-desktop-lab.config.ragos.profile.name
nix --extra-experimental-features 'nix-command flakes' eval path:$PWD#nixosConfigurations.ragos-client-hyperv-debug.config.ragos.profile.name
nix --extra-experimental-features 'nix-command flakes' eval path:$PWD#nixosConfigurations.ragos-client-rescue-minimal.config.ragos.profile.name
./scripts/tests/test-clients-inventory-validation.sh
./scripts/tests/test-client-inventory-routing.sh
./scripts/tests/test-brandlab-contract.sh
./scripts/tests/test-day0-contract.sh
./scripts/tests/test-ragc-phaseA.sh
./scripts/tests/test-ragc-channels.sh
./scripts/tests/test-runtime-guardrails.sh
./scripts/tests/test-client-group-sector-mount-contract.sh
./scripts/tests/test-server-access-contract.sh
./scripts/tests/test-client-lab-serial-contract.sh
./scripts/tests/test-client-boot-surface-contract.sh
./scripts/tests/test-installer-live-media-contract.sh
```

## Perfis oficiais do cliente

- `desktop-generic`: producao fisica
- `desktop-lab`: laboratorio fisico
  no lab libvirt, este perfil preserva `tty1` e expõe `ttyS0` como fallback serial de prova
  e hoje sobe em modo verboso, sem Plymouth
- `hyperv-debug`: laboratorio/CI em Hyper-V
  tambem sobe em modo verboso, sem Plymouth
- `rescue-minimal`: recuperacao minima

## Contrato atual do cliente

- estado atual implementado: root por `/nix/store` remoto via NFS (ro) + overlay tmpfs (rw)
- persistencia: `/home` em NFSv4
- setores compartilhados: login real -> `/home/<usuario>` -> `~/Setores/<grupo>`
- roadmap: migracao futura para netboot/SquashFS

Para validar o contrato de setores do cliente sem depender de lab destrutivo:

```bash
./scripts/tests/test-client-group-sector-mount-contract.sh
```

## Publicar no servidor

Depois de validar no checkout de desenvolvimento:

```bash
git status
git add -A
git commit -m "fix(<escopo>): resumo"
```

No host operacional:

```bash
cd /etc/ragos
git pull --ff-only
git submodule update --init --recursive
sudo ragos switch
sudo ragc switch --channel generic
ragc doctor
```

## Guardrails

- nao editar `/etc/ragos` como workspace principal
- nao misturar incidente operacional e refatoracao no mesmo commit
- nao publicar `rescue-minimal` sem `current` bootavel
- nao tratar `hyperv-debug` como baseline de hardware fisico
- nao atualizar docs sem refletir estado real do codigo
- nao mudar branding sem atualizar o ciclo do BrandLab quando a superficie real mudar
