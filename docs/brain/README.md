# Kryonix Brain

O Kryonix Brain é a infraestrutura de Inteligência Artificial nativa do projeto Kryonix. Ele transforma um host (normalmente o `glacier`) em um servidor robusto de Inferência, RAG (Retrieval-Augmented Generation) e Graph Database, servindo o resto da rede local.

## Componentes
- **LLM Engine:** Ollama (com gerenciamento agressivo de VRAM via `systemd` e `nvidia-smi`).
- **Graph Database:** Neo4j (isolado via Tailscale).
- **Control Plane:** `kryonix-brain-api` (Uma API FastAPI provida pelo pacote `kryonix-brain-lightrag`).
- **Persistência:** Todo o estado do Brain vive restrito em `/var/lib/kryonix/brain/`.

## Topologia
O Brain segue um modelo Cliente/Servidor:
- **Server Role:** Roda no Glacier, levantando a API na porta 8000 e escutando na interface `tailscale0`.
- **Client Role:** Roda no Inspiron ou outras estações, não instanciando o banco nem a API pesada, mas criando um túnel seguro (SSH/Tailscale) e expondo wrappers locais (`kryonix-search`, `kryonix-stats`) que falam de forma transparente com o servidor.

## Links Rápidos
- [Arquitetura RAG/CAG/GraphRAG](RAG_CAG_GRAPHRAG.md)
- [Neo4j e Grafo](NEO4J.md)
- [A Camada de Memória (Obsidian)](MEMORY.md)
