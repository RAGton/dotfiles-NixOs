# Implementar o Kryonix Vault em qualquer projeto

Este guia mostra como usar este vault como **cérebro de IA reutilizável** para qualquer projeto: backend, frontend, NixOS, Proxmox, automação, SaaS, scripts, infraestrutura ou estudos.

## Objetivo

Fazer qualquer IA/agente trabalhar com:

- contexto técnico persistente;
- padrões de engenharia definidos;
- menor mudança correta;
- segurança por padrão;
- testes e validação;
- documentação mínima útil;
- menos custo com tokens;
- decisões técnicas rastreáveis.

## Modelo mental

```txt
Kryonix Vault = conhecimento global
Projeto atual = contexto local
AGENTS.md = contrato de execução
Issue = escopo de trabalho
Testes = validação objetiva
Humano = decisão final
```

## Passo 1 — Instalar como submódulo opcional

Dentro de um projeto:

```bash
git submodule add https://github.com/RAGton/kryonix-vault.git .ai/kryonix-vault
git commit -m "Add Kryonix Vault as AI knowledge base"
```

Atualizar depois:

```bash
git submodule update --remote .ai/kryonix-vault
git add .ai/kryonix-vault
git commit -m "Update Kryonix Vault"
```

## Passo 2 — Copiar o AGENTS.md

Para projetos pequenos:

```bash
cp .ai/kryonix-vault/AGENTS.md ./AGENTS.md
```

Para projetos grandes, mantenha o global e crie um local:

```txt
AGENTS.md
.ai/kryonix-vault/AGENTS.md
```

No `AGENTS.md` local, declare:

```md
# Projeto atual

Antes de executar qualquer tarefa, consulte:

- .ai/kryonix-vault/README.md
- .ai/kryonix-vault/PROMPT_MASTER.md
- .ai/kryonix-vault/01-MOCs/Mapa - Cerebro Supremo de IA.md

Priorize este repositório local quando houver conflito com o vault global.
```

## Passo 3 — Criar contexto local do projeto

Crie:

```txt
PROJECT_CONTEXT.md
ARCHITECTURE.md
SECURITY.md
OPERATIONS.md
DECISIONS.md
```

Modelo mínimo de `PROJECT_CONTEXT.md`:

```md
# Project Context

## Objetivo

## Stack

## Comandos

- format:
- lint:
- test:
- build:
- check:

## Áreas críticas

## Fora do escopo para agentes

## Contratos públicos

## Segurança

## Deploy e rollback
```

## Passo 4 — Usar com IA/agente

Prompt inicial para qualquer IA:

```txt
Use o Kryonix Vault como fonte prioritária de contexto.
Leia primeiro:

1. .ai/kryonix-vault/README.md
2. .ai/kryonix-vault/AGENTS.md
3. .ai/kryonix-vault/PROMPT_MASTER.md
4. .ai/kryonix-vault/01-MOCs/Mapa - Cerebro Supremo de IA.md
5. PROJECT_CONTEXT.md do projeto atual

Prioridade:
- projeto atual vence o vault global;
- vault vence memória do modelo;
- documentação oficial vence opinião;
- se houver risco operacional, peça validação humana.
```

## Passo 5 — Criar issues pequenas para agentes

Formato recomendado:

```md
## Objetivo

Implementar/fixar/revisar <algo específico>.

## Escopo permitido

- arquivo/pasta A
- arquivo/pasta B

## Fora do escopo

- refatoração global
- dependências novas
- deploy
- secrets

## Critério de aceite

- teste X passa
- lint passa
- contrato não quebra
- documentação atualizada se necessário

## Validação

```bash
<commands>
```
```

## Passo 6 — Usar Skills

Consulte `05-Skills/` para tarefas recorrentes:

- revisão de PR;
- geração de testes;
- revisão de segurança;
- backend/API;
- NixOS hardening;
- debug produção;
- análise de performance;
- frontend moderno;
- decomposição para Codex.

## Passo 7 — Segurança mínima

Nunca permita agente fazer automaticamente:

- apagar banco;
- rodar migration destrutiva;
- alterar secrets;
- fazer deploy produção;
- abrir firewall;
- mudar boot/kernel/firewall de host;
- mexer em billing/pagamento;
- alterar autorização sem teste.

Exija sempre:

- backup quando houver risco;
- dry-run quando disponível;
- rollback documentado;
- logs sem secrets;
- teste de falha;
- revisão humana.

## Passo 8 — Padrão de consumo por projeto

### Backend/API

Usar:

- `02-Areas/Backend e APIs/`
- `05-Skills/arquitetura-backend/`
- `05-Skills/revisao-seguranca-api/`
- `07-Prompts/PROMPT_AGENT_BACKEND_API.md`

### Frontend moderno

Usar:

- `02-Areas/Frontend Moderno/`
- `01-MOCs/Mapa - Frontend Moderno.md`
- `07-Prompts/PROMPT_AGENT_SITE_MODERNO.md`

### Linux/NixOS/Proxmox

Usar:

- `02-Areas/Linux e Sistemas/`
- `02-Areas/NixOS e Infra Declarativa/`
- `01-MOCs/Mapa - Proxmox PXE NFS Homelab.md`
- `07-Prompts/PROMPT_AGENT_INFRA_LINUX.md`

## Checklist final

- [ ] Vault conectado ao projeto
- [ ] AGENTS.md presente
- [ ] PROJECT_CONTEXT.md criado
- [ ] comandos de validação documentados
- [ ] secrets protegidos
- [ ] escopo do agente limitado
- [ ] issue pequena criada
- [ ] testes obrigatórios
- [ ] rollback considerado
