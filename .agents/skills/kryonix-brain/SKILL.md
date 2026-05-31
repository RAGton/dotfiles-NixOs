---
name: kryonix-brain
description: Opera o sistema Brain do kryonix — LightRAG + Neo4j + Ollama + CAG no glacier. Use quando a tarefa envolver kryonix brain search/ask/index/cag, a API do Brain (porta 8000), indexação de documentos, diagnóstico do grafo de conhecimento, kora (assistente de voz/texto), rotas CAG, ou qualquer problema com os serviços kryonix-brain-api, kryonix-lightrag ou ollama no glacier.
---

# Kryonix Brain

## Stack

```
glacier (servidor)
├── Ollama          :11434  — inferência LLM local (GPU, qwen2.5-coder:7b padrão)
├── LightRAG        —       — motor GraphRAG: NanoVectorDB + GraphML
├── Neo4j           :7687   — grafo avançado (Bolt), :7474 (HTTP)
├── Brain API       :8000   — FastAPI, auth: X-API-Key
└── Kora            —       — assistente voz/texto (kora ask, kora listen)

inspiron (cliente)
└── kryonix brain * — CLI que chama Brain API via Tailscale/LAN
```

Arquivos-chave:
- `modules/nixos/services/brain.nix` — serviços NixOS
- `packages/kryonix-brain-lightrag/` — código Python do Brain
- `brain.env` — KRYONIX_BRAIN_API_KEY, KRYONIX_BRAIN_URL
- `docs/brain/` — arquitetura, CAG, Neo4j schema

## Decisão CAG vs RAG

```
Query técnica sobre kryonix?
  └── kryonix brain cag ask "<query>"    → CAG: resposta rápida de arquivos cacheados
                                            (NixOS modules, CLI contract, arquitectura)
Query sobre conhecimento geral/vault?
  └── kryonix brain search "<query>"    → RAG híbrido: GraphML + embeddings + Ollama
Query de diagnóstico do grafo?
  └── kryonix brain graph stats/doctor  → Neo4j / GraphML direto
```

## Comandos essenciais

```bash
# Consulta
kryonix brain ask "<pergunta>"           # RAG híbrido (padrão)
kryonix brain cag ask "<pergunta>"       # CAG — técnico, rápido
kryonix brain chunks "<query>"           # Somente vetores (sem síntese)

# Grafo
kryonix brain stats                      # Contagem: entidades, relações, docs
kryonix brain graph stats                # Status do Neo4j
kryonix brain graph doctor               # Diagnóstico de integridade
kryonix brain top [N]                    # Top-N entidades por grau
kryonix brain find "<entidade>"          # Buscar entidade no grafo
kryonix brain show "<entidade>"          # Detalhes + vizinhos

# Indexação
kryonix brain index [path] [--full|--incremental|--dry-run]
kryonix brain insert "<texto>" --source LABEL

# CAG
kryonix brain cag build                  # Montar pacote de contexto
kryonix brain cag status                 # Status do pack CAG
kryonix brain cag route "<query>"        # Arquivos relevantes para a query

# Diagnóstico
kryonix brain health                     # Health check da API
kryonix brain diagnostics                # Auditoria profunda de grounding
```

## Serviços no glacier

```bash
systemctl status kryonix-brain-api      # API principal
systemctl status kryonix-lightrag       # Warmup do grafo (oneshot)
systemctl status ollama                  # Motor LLM

journalctl -u kryonix-brain-api -n 50 --no-pager
journalctl -u ollama -n 30 --no-pager
```

## API direta (quando CLI não resolve)

```bash
# Requer: X-API-Key do brain.env
curl -s http://glacier:8000/health
curl -s http://glacier:8000/stats
curl -s -X POST http://glacier:8000/search \
  -H "X-API-Key: $KRYONIX_BRAIN_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "como funciona o CAG", "mode": "hybrid"}'
```

## Caminhos de storage (glacier)

```
/var/lib/kryonix/brain/
├── storage/     # GraphML + NanoVectorDB (LightRAG)
├── cag/         # Context cache, prompt cache, invalidation markers
└── vault/       # Obsidian vault técnico sincronizado
```

## Validação de saída

```bash
kryonix brain health
kryonix brain stats
kryonix brain diagnostics
```

## Riscos

- Ollama usa VRAM do glacier — não indexar ou consultar durante sessão de gaming sem `kryonix ollama stop`
- CAG stale: rebuild com `kryonix brain cag build` após mudança de módulos ou flake.lock
- Brain API não responde: verificar se kryonix-lightrag.service completou antes de kryonix-brain-api
- Nunca usar `/ingest/apply` sem revisar `/ingest/propose` + `/ingest/queue` antes
