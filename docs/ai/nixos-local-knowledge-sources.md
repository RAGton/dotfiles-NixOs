---
type: local-knowledge-source
domain: nixos
component: local-sources
status: canonical
graph_group: nixos-sources
tags:
  - nixos
  - nixpkgs
  - home-manager
  - noogle
  - kryonix/rag/source
---

# Bancos Locais NixOS para CAG/RAG

Diretório base dos bancos locais:

```txt
/var/lib/kryonix/sources/nixos
```

## Fontes locais disponíveis

```txt
/var/lib/kryonix/sources/nixos/nixpkgs
/var/lib/kryonix/sources/nixos/nixos-search
/var/lib/kryonix/sources/nixos/nix-dev
/var/lib/kryonix/sources/nixos/home-manager
/var/lib/kryonix/sources/nixos/nixos-hardware
/var/lib/kryonix/sources/nixos/noogle-data.json
```

## Regra de uso

Estas fontes são bases locais de referência NixOS/Nix/Home Manager para alimentar CAG/RAG.

Prioridade de resposta:

1. Documentação canônica do Kryonix em `/etc/kryonix/docs`.
2. Configuração declarativa em `/etc/kryonix`.
3. Fontes locais em `/var/lib/kryonix/sources/nixos`.
4. Se não houver grounding, responder que não há contexto suficiente.

## Política operacional

Para ações no sistema Kryonix, usar somente o CLI `kryonix`.

Comandos operacionais permitidos:

```bash
kryonix switch
kryonix home
kryonix brain cag build
kryonix brain cag status
kryonix brain cag route "pergunta"
kryonix brain cag ask "pergunta"
kryonix brain search "pergunta"
```

Não sugerir comandos brutos de operação do sistema quando houver equivalente `kryonix`.
