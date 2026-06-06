---
source: docs/brain/mcp.md
status: derived
canonical: false
last_sync: 2026-05-01
---

# MCP (Model Context Protocol)

> [!IMPORTANT]
> Esta nota é derivada de `docs/`. Em caso de divergência, `docs/` vence.

O Kryonix integra servidores de **Model Context Protocol** para interações locais JSON-RPC isoladas.

## Fonte de Verdade
- **Status:** **VALIDATED** (Servidores locais operacionais)
- **Serviço:** N/A (Cada server roda sob demanda invocado pelo agent client)
- **Porta:** N/A (A comunicação é via standard I/O streams)
- **Comando:** `kryonix mcp doctor`
- **Validação:** Todos os servidores configurados no `.mcp.json` retornando check verde.

## Servidores MCP Suportados
A arquitetura de integração inclui:
1. **mcp-nixos**: Expõe acesso seguro a opções do NixOS e pacotes.
2. **Filesystem**: Exposição _read-only_ do Vault.

> [!WARNING]
> A inicialização remota do **Brain MCP (`kryonix-brain`)** do `glacier` a partir de hosts clientes está classificada como PARTIAL no ROADMAP e não constitui feature plenamente validada em runtime oficial.

## Validação de Segurança e Variáveis 
A regra principal para o MCP é que **nenhum secret deve ser incluído em arquivos locais do repositório**. 
- O arquivo `.mcp.json` é ignorado pelo GIT (`.gitignore`).
- Apenas a cópia `.mcp.example.json` deve ser manipulada ou enviada no versionamento.
- Caminhos para servidores locais precisam ser sempre absolutos.

## Testes do MCP

Os comandos abaixo são necessários para validar se sua integração foi feita corretamente, protegendo o vazamento de segredos via `stdout`:
```sh
kryonix mcp check        # Analisa o config atrás de secrets expostos
kryonix mcp doctor       # Confirma vitalidade dos servers
```
