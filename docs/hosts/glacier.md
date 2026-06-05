# Host: Glacier

Este documento descreve o papel do host **Glacier** na arquitetura Kryonix.

## Função
O Glacier é o **Servidor e Cérebro de IA Primário** do projeto. Ele atua como o servidor backend pesado, hospedando Modelos de Linguagem (LLMs), a Graph Database e fornecendo os túneis para o Client.

## Onde vive o código real
> [!IMPORTANT]
> **O Host Glacier NÃO EXISTE neste repositório upstream.**
> Todas as definições de discos, bootloaders e hardware do Glacier estão armazenadas no repositório **Downstream (`/etc/kryonixos/hosts/glacier`)**.
> O Upstream fornece a inteligência e os packages, que o downstream instancia.

## Serviços e Features Esperadas (Profile)
- **Profile:** Herda primariamente de `profiles/glacier-ai.nix`.
- **Serviços de IA Core:**
  - `ollama` (Aceleração CUDA).
  - `kryonix-brain-api` (Servidor de FastAPI na porta 8000).
  - `neo4j` (Banco de Dados em Grafo local).
- **Armazenamento:** Estrutura padronizada de arquivos em `/var/lib/kryonix/brain/`.
- **Ambiente Gráfico:** Ausente ou limitado (Servidor headless primariamente).
- **Conectividade:** Tailscale ativo (`100.64.x.x`), aceitando tráfego do cliente Inspiron para porta 8000 e via SSH.

## O que está implementado vs Roadmap
- Motor de IA Base (LightRAG, Ollama, API FastAPI): Implementado.
- Perfilamento de VRAM Dinâmico: Implementado (via wrappers antes do systemd start).
- GraphRAG reasoning agents no topo: Roadmap (atualmente só suporta queries RAG/CAG diretas).
