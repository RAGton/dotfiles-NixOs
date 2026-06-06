# MCP Architecture (Model Context Protocol)

## O que é
O MCP é um protocolo aberto que permite que modelos de linguagem (LLMs) acessem dados e ferramentas de forma segura e padronizada. No Kryonix, ele é a ponte entre o seu editor (Obsidian/Cursor) e o Kryonix Brain (LightRAG).

## Como funciona
A arquitetura baseia-se em um modelo **Cliente-Servidor**.

### Componentes no Kryonix:
1. **MCP Server**: Implementado em `kryonix_brain_lightrag.server`. Ele expõe ferramentas (`tools`) e recursos (`resources`).
2. **Transporte**: Usa STDIO (entrada/saída padrão) para comunicação entre o host (Obsidian/Cursor) e o servidor Python. A comunicação segue o padrão JSON-RPC 2.0.
3. **Tools (Ferramentas)**: Funções Python que o LLM pode invocar (ex: `query_brain`, `get_stats`). O servidor usa o SDK do MCP para Python (`mcp`).

### Fluxo de Comunicação:
- O Usuário pergunta no Obsidian.
- O Plugin MCP no Obsidian chama `kryonix-brain` via STDIO.
- O Servidor Python recebe a chamada JSON-RPC, executa a busca no RAG e retorna o contexto formatado.
- O LLM usa esse contexto para responder.

## Uso prático
O servidor MCP é configurado no arquivo `.mcp.json` na raiz do repositório.

### Configuração Típica:
```json
{
  "mcpServers": {
    "kryonix-brain": {
      "command": "uv",
      "args": [
        "run",
        "--project",
        "packages/kryonix-brain-lightrag",
        "python",
        "-m",
        "kryonix_brain_lightrag.server"
      ]
    }
  }
}
```

## Ferramentas Disponíveis:
- `query_brain`: Consulta o grafo e VDB (híbrido).
- `get_stats`: Mostra o estado do banco de dados.
- `index_workspace`: Aciona a indexação incremental.

## Problemas comuns
- **STDIO Pollution**: Logs de `print()` no código Python podem quebrar o protocolo JSON-RPC. Use `logging` ou redirecione para `stderr`.
- **Caminhos Absolutos**: O plugin MCP muitas vezes requer caminhos absolutos no `.mcp.json` para funcionar corretamente fora do shell do projeto.
- **Ambiente Virtual**: Falha ao encontrar dependências se o `uv` não estiver no PATH ou o projeto não estiver sincronizado.

## Boas práticas
- Sempre valide o registro com `kryonix mcp check`.
- Mantenha o servidor leve; processamento pesado deve ser assíncrono ou delegado para a CLI.
- Use descrições claras nas ferramentas MCP, pois o LLM as usa para decidir qual ferramenta chamar.

## Links
- [[01-MOCs/Mapa - IA e Agentes]]
- [[02-Areas/IA e Agentes/RAG Pipeline Interno]]
- [Official MCP Documentation](https://modelcontextprotocol.io)
