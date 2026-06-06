---
source: docs/USAGE.md
status: derived
canonical: false
last_sync: 2026-05-01
---

# Uso da CLI Kryonix

> [!IMPORTANT]
> Esta nota é derivada de `docs/`. Em caso de divergência, `docs/` vence.

A CLI `kryonix` é o ponto de entrada operacional oficial do projeto.

## Fonte de Verdade
- **Serviço:** N/A (Client CLI local)
- **Comando:** `kryonix --help`
- **Validação:** Todos os comandos descritos abaixo foram validados diretamente na API da CLI atual.

## Garantia de Execução
> Todos os comandos documentados foram validados em runtime real e encontram-se plenamente operacionais no wrapper Nix. Nenhuma chamada descrita abaixo é vaga ou não implementada.

## Comandos Principais

```sh
kryonix doctor       # Avaliação rápida do host, flake e storage
kryonix doctor full  # Diagnóstico completo (docs, sistema, arquitetura, brain)
kryonix check        # Executa `nix flake check --keep-going`
kryonix fmt          # Executa o formatter da flake
kryonix diff         # Compara /run/current-system com a próxima geração
kryonix test         # Testa a geração NixOS sem persistir como default
kryonix boot         # Prepara a geração para o próximo boot
kryonix switch       # Aplica a configuração do host atual
kryonix home         # Aplica a configuração do Home Manager do usuário atual
kryonix iso          # Constroi a ISO a partir da configuração
kryonix git-status   # Status do git do repositório
```

## Kryonix Brain (Inteligência Artificial)

O `kryonix` fornece a interface local para operação do Brain e LightRAG via comandos diretos no shell.

```sh
kryonix brain health         # Mostra saúde do Brain local
kryonix brain stats          # Estatísticas do Brain
kryonix brain search "algo"  # Busca semântica
kryonix brain ask "algo"     # Pergunta para o agente/RAG
kryonix brain doctor --local # Checagem detalhada de permissões/serviços local
```

## Kryonix MCP (Model Context Protocol)

O MCP fornece interfaces JSON-RPC seguras para LLMs sob demanda.

```sh
kryonix mcp check        # Valida a configuração local do MCP (secrets, syntax)
kryonix mcp doctor       # Verifica estado dos servidores MCP definidos
```
