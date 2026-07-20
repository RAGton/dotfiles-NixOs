# Integração MCP do Kryonix

O Kryonix usa MCP via JSON-RPC sobre `stdio`. Integrações novas não devem
abrir portas HTTP/SSE locais por padrão.

## Estado real

| Servidor | Transporte | Segurança | Estado |
|---|---|---|---|
| `kryonix-brain` | SSH + stdio no Glacier | ferramentas próprias com contrato restrito | PARTIAL: requer prova no Glacier |
| `mcp-nixos` | stdio local | rede liberada, sem acesso ao filesystem do host | implementado, opt-in |
| `vault-readonly` | stdio local | `bubblewrap` + raízes em `--ro-bind` | implementado, opt-in |
| `git-readonly` | stdio local | `bubblewrap` + um repo em `--ro-bind` | implementado, opt-in |
| `sequential-thinking` | stdio local | sem rede, home efêmero, sem acesso ao host | implementado, opt-in |

Hermes foi aposentado. Os wrappers MCP são independentes do agente cliente e
podem ser consumidos por Codex, Claude, Cursor ou outro host compatível.

## Limite de confiança

Os servidores upstream de filesystem e Git **não são read-only**:

- `mcp-server-filesystem` anuncia ferramentas de escrita, edição e movimento;
- `mcp-server-git` anuncia operações mutantes sobre o repositório.

O Kryonix não confia em prompt, nome do servidor ou `readOnlyHint` para impor
segurança. Os wrappers em `modules/nixos/features/mcp.nix` isolam o processo,
limpam o ambiente, removem a rede e montam somente os caminhos autorizados como
read-only. Uma chamada mutante pode aparecer no catálogo upstream, mas deve
falhar no limite do kernel.

## Configuração NixOS

Exemplo opt-in para o Inspiron de desenvolvimento:

```nix
{
  kryonix.features.mcp = {
    filesystem = {
      enable = true;
      roots = [
        "/home/rocha/kryonix/kryonix-dev/repos/kryonix"
        "/home/rocha/kryonix/kryonix-dev/repos/kryonix-vault"
      ];
    };

    git = {
      enable = true;
      repositories = [
        "/home/rocha/kryonix/kryonix-dev/repos/kryonix"
      ];
    };

    sequentialThinking.enable = true;
    nixos.enable = true;
  };
}
```

As opções rejeitam caminhos relativos, `/` e allowlists vazias. Nada é
habilitado automaticamente em host algum.

## Configuração do cliente

Depois de fazer build e ativar a configuração NixOS, copie
`.mcp.example.json` para o arquivo local esperado pelo cliente. Para Codex, o
equivalente é:

```toml
[mcp_servers.vault-readonly]
command = "/run/current-system/sw/bin/kryonix-mcp-filesystem-readonly"
args = []

[mcp_servers.git-readonly]
command = "/run/current-system/sw/bin/kryonix-mcp-git-readonly"
args = ["/home/rocha/kryonix/kryonix-dev/repos/kryonix"]

[mcp_servers.sequential-thinking]
command = "/run/current-system/sw/bin/kryonix-mcp-sequential-thinking"
args = []

[mcp_servers.mcp-nixos]
command = "/run/current-system/sw/bin/kryonix-mcp-nixos"
args = []
```

O caminho passado ao wrapper Git deve corresponder exatamente a uma entrada de
`kryonix.features.mcp.git.repositories`.

## Brain remoto

No Inspiron, o Brain pesado continua no Glacier:

```toml
[mcp_servers.kryonix-brain]
command = "/run/current-system/sw/bin/ssh"
args = [
  "glacier",
  "cd /etc/kryonix && /run/current-system/sw/bin/uv run --project packages/kryonix-brain-lightrag kg-server",
]
required = false
startup_timeout_sec = 30.0
```

Esse fluxo usa SSH como transporte de `stdio`; não requer autenticação MCP em
porta local. A autenticação e autorização são as do SSH. Seu estado runtime
permanece PARTIAL até teste real no Glacier.

## Fora de escopo

- GitHub MCP não é habilitado: o catálogo anterior exigia token e oferecia
  operações mutantes. Clientes com plugin GitHub próprio devem aplicar RBAC no
  próprio conector.
- Fetch/Context7 não são habilitados: adicionam rede, SSRF e custo operacional.
- Memory MCP não é habilitado: duplicaria Brain/Vault e introduziria escrita.
- Não existe `rag-slim-wrapper` no código atual. Limite obrigatório de output e
  paginação continuam como pendência; respostas grandes não devem ser descritas
  como mitigadas.

## Validação

Antes de ativar em um host:

```bash
nix flake check --keep-going
git diff --check
```

Depois do build, a prova mínima deve cobrir:

1. handshake MCP e `tools/list` dos três wrappers;
2. leitura de um arquivo e consulta Git permitidas;
3. tentativa de escrita no filesystem e mutação Git falhando;
4. caminho Git fora da allowlist falhando;
5. servidor de pensamento sem rede e sem persistência no home real.

Não executar `switch` antes dessas provas e do build do host.

## Referências locais

- `modules/nixos/features/mcp.nix`
- `.mcp.example.json`
- `docs/mcp/security.md`
- `docs/mcp/client-configs.md`
- `docs/brain/mcp.md`
