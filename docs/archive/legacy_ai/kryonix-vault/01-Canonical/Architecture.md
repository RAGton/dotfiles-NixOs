---
source: docs/ARCHITECTURE.md
status: derived
canonical: false
last_sync: 2026-05-01
---

# Arquitetura Kryonix

> [!IMPORTANT]
> Esta nota é derivada de `docs/`. Em caso de divergência, `docs/` vence.

Esta página define a arquitetura real e atual do projeto Kryonix.

## Fonte de Verdade
- **Serviço Principal Ativo:** `ollama.service` (no Glacier)
- **Porta:** `11434`
- **Validação Estrutural:** `nix flake check --keep-going`

## Resumo Arquitetural
A arquitetura do projeto separa claramente clientes de servidores, organizando configurações através de NixOS flakes. 

A base atual entrega:
- múltiplos hosts (`inspiron`, `inspiron-nina`, `glacier`, `iso`)
- múltiplos usuários (`rocha`, `nina`)
- namespace primário `kryonix.*`
- aliases legados internos temporários
- `hosts/common/default.nix` como agregador compartilhado
- stack desktop **Hyprland** com **Caelestia** como shell principal
- CLI operacional primária `kryonix`

## Árvore do Repositório

```txt
Kryonix repo
├── flake.nix
├── hosts/
│   ├── inspiron/
│   ├── glacier/
│   └── common/
├── modules/
│   └── nixos/
├── profiles/
├── features/
├── home/
├── desktop/
│   └── hyprland/
├── packages/
├── overlays/
├── docs/
├── docs/ai/
├── context/
├── scripts/
└── skills/
```

## Separação Cliente / Servidor
A arquitetura oficial separa o papel de servidor de inteligência artificial (Glacier) do cliente para uso diário e desenvolvimento (Inspiron).

```txt
Inspiron (Cliente Leve/Workstation)
  -> LAN/Tailscale
  -> Glacier (Servidor IA/Datacenter)
  -> Ollama :11434
```

> [!NOTE]
> O cliente não processa os LLMs pesados. Outros serviços como Brain API e LightRAG remoto estão em fase de implementação e documentados no ROADMAP. Apenas conexões validadas (como o daemon nativo do Ollama) são consideradas como prontas em nível arquitetural de runtime isolado.
