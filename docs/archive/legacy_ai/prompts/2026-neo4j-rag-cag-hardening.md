# Prompt para Agente — Incrementar AGENTS.md e endurecer Kryonix Brain

Você está trabalhando no repositório Kryonix em `/etc/kryonix`.

## Objetivo

Aplicar o pacote de contexto GraphRAG/CAG/Neo4j/Obsidian de forma segura, incremental e validada.

## Regras obrigatórias

- Leia `AGENTS.md` antes de qualquer alteração.
- Código real vence documentação.
- Não rode switch/reboot/disko/mkfs/sudo sem aprovação explícita.
- Não indexe secrets.
- Não mova dados de `/var/lib` sem backup.
- Não substitua Obsidian por Neo4j.
- Neo4j deve ser índice/grafo derivado, reconstruível e local ao Glacier.
- Faça commits pequenos.

## Tarefas

1. Comparar o `AGENTS.md` atual com `AGENTS_INCREMENT_GRAPH_RAG_CAG.md`.
2. Integrar as seções 38–44 ao `AGENTS.md` sem remover regras existentes.
3. Criar/atualizar docs:
   - `docs/brain/OBSIDIAN_NEO4J_MODEL.md`
   - `docs/brain/STATE_LAYOUT.md`
   - `docs/brain/RAG_ARCHITECTURE.md`
   - `docs/brain/CAG_ARCHITECTURE.md`
   - `docs/brain/GRAPH_RAG_ARCHITECTURE.md`
   - `docs/brain/INGESTION_PIPELINE.md`
   - `docs/brain/REASONING_MEMORY.md`
4. Criar workflow:
   - `.agents/workflows/brain-graphrag-cag-hardening.md`
5. Auditar pastas soltas na raiz, especialmente `skills/`, antes de mover qualquer coisa.
6. Planejar ingestão do repo inteiro, incluindo `.nix`, com exclusions de secrets.
7. Validar.

## Comandos de validação

```bash
cd /etc/kryonix

git status --short
git diff --stat
git diff

nix fmt . || true
nix flake check --keep-going
nh os build .#glacier -L --show-trace
```

Se Brain runtime estiver disponível:

```bash
kryonix brain health
kryonix brain stats
kryonix brain search "Como funciona o pipeline RAG do Kryonix?"
systemctl status ollama --no-pager
systemctl status kryonix-lightrag --no-pager
systemctl status kryonix-brain-api --no-pager
```

Se Neo4j for habilitado:

```bash
systemctl status neo4j --no-pager
cypher-shell "RETURN 1 AS ok;"
```

## Relatório final

Responder com:

```txt
Status:
Arquivos alterados:
O que mudou:
Validação executada:
Resultado dos testes:
Riscos:
Rollback:
Pendências:
```
