# BRAIN_SERVER_ARCHITECTURE

## Overview

Kryonix uses a distributed Brain architecture to separate heavy AI workloads from daily workstation tasks. The system is fully declarative via NixOS.

### Topology

- **Glacier (Server)**:
  - Role: Central Intelligence Server & IA Powerhouse.
  - OS: NixOS (Declarative).
  - Services: 
    - Ollama (LLM/Embeddings) - Accelerated by NVIDIA RTX 4060.
    - Kryonix Brain API (FastAPI wrapper for LightRAG).
    - LightRAG Storage (Knowledge Graph & Vector DB).
    - Obsidian Vault (Canonical Technical Brain).
    - MCP (Model Context Protocol) Server.
  - Connectivity: 
    - LAN: `10.0.0.2`
    - Tailscale: (Configured for remote access)
    - SSH Port: `2224`

- **Inspiron (Client)**:
  - Role: Daily Workstation & Development Environment.
  - OS: NixOS.
  - Services:
    - Kryonix CLI (Brain Client).
    - Desktop (Hyprland/Caelestia).
  - Connectivity: Accesses Glacier via LAN or Tailscale.

## Service Map

### Brain API
- **Endpoint**: `http://10.0.0.2:8000` (LAN) / `http://glacier:8000` (Tailscale)
- **Auth**: `X-API-Key` (Defined in `/etc/kryonix/brain.env`).
- **Endpoints**:
  - `/health`: System health and storage status.
  - `/stats`: Graph metrics (entities, relations, docs).
  - `/search`: RAG query with sources and grounding.

### Ollama
- **Endpoint**: `http://10.0.0.2:11434`
- **Primary Models**:
  - LLM: `qwen2.5-coder:7b` (Default)
  - Embedding: `nomic-embed-text:latest`
- **VRAM Optimization**: `keep_alive=0` ensures the GPU is freed immediately after inference, supporting the "Gamer Server" profile.

## Storage & Persistence

- **Location**: Managed via `kryonix.services.brain` options.
  - Storage: `/var/lib/kryonix/brain/storage`
- **Format**: LightRAG Knowledge Graph (GraphML) + NanoVectorDB.
- **Integrity**: Guaranteed by atomic writes and validated via `kryonix brain health`.

## Security

- **Network**: Communication restricted to LAN (`br0`) and Tailscale (`tailscale0`) via NixOS firewall.
- **Secrets**: `KRYONIX_BRAIN_API_KEY` is stored in `/etc/kryonix/brain.env` (permissions 600) and never committed to Git.
- **Access**: Managed via `kryonix.services.brain.user` and `group` (Default: `rocha:users`).

## Operational Workflow

1. **Deployment**: Fully declarative via `nh os switch` or `nixos-rebuild`.
2. **Startup**: `ollama`, `kryonix-lightrag`, and `kryonix-brain-api` start automatically on boot (configured in `glacier-ai` profile).
3. **Indexing**: Controlled ingestion via `kryonix brain ingest`.
4. **Maintenance**: Periodic health checks via `kryonix-brain-doctor`.
