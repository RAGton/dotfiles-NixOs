# Configuração de clientes MCP

Os wrappers abaixo só existem no PATH após habilitar as opções correspondentes
em `kryonix.features.mcp` e ativar uma geração NixOS previamente construída.

## Codex

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

[mcp_servers.kryonix-brain]
command = "/run/current-system/sw/bin/ssh"
args = [
  "glacier",
  "cd /etc/kryonix && /run/current-system/sw/bin/uv run --project packages/kryonix-brain-lightrag kg-server",
]
required = false
startup_timeout_sec = 30.0
```

## Clientes JSON

Use `.mcp.example.json` como base e mantenha a cópia local `.mcp.json` fora do
Git. Não adicione tokens ao JSON.

## Contrato dos wrappers

### `kryonix-mcp-filesystem-readonly`

- não recebe argumentos do cliente;
- expõe somente `kryonix.features.mcp.filesystem.roots`;
- monta cada raiz read-only;
- não herda rede, home ou ambiente do cliente.

O servidor upstream ainda lista ferramentas mutantes. Elas devem falhar com
erro de filesystem read-only.

### `kryonix-mcp-git-readonly`

- recebe exatamente um caminho absoluto;
- o caminho deve estar em `kryonix.features.mcp.git.repositories`;
- cada execução enxerga somente o repo selecionado;
- staging, commit, checkout mutante ou escrita no working tree devem falhar.

### `kryonix-mcp-sequential-thinking`

- não recebe argumentos;
- roda sem rede e sem acesso aos repositórios;
- usa home e `/tmp` efêmeros;
- define `DISABLE_THOUGHT_LOGGING=true` para não duplicar pensamentos em logs.

### `kryonix-mcp-nixos`

- usa o pacote pinado no nixpkgs, sem `uv tool run` ou download em runtime;
- possui rede para consultar as fontes NixOS;
- não recebe mounts do host nem o ambiente do cliente.

### `kryonix-brain`

- no Inspiron, roda no Glacier via SSH + stdio;
- não requer porta MCP local;
- autenticação é a do SSH;
- permanece PARTIAL até handshake e chamadas reais no Glacier.

## Servidores não registrados

- `mcp-server-filesystem` direto: write-capable;
- `mcp-server-git` direto: write-capable;
- GitHub MCP: requer RBAC/token e oferece mutações;
- Fetch/Context7: rede e risco de SSRF/custo;
- Memory: persistência duplicada em relação ao Brain/Vault.

## Diagnóstico

```bash
command -v kryonix-mcp-filesystem-readonly
command -v kryonix-mcp-git-readonly
command -v kryonix-mcp-sequential-thinking
command -v kryonix-mcp-nixos
kryonix mcp check
```

Se `bubblewrap` falhar por user namespaces desabilitados, o servidor deve ser
tratado como BROKEN; não substituir o wrapper pelo binário upstream para fazê-lo
“funcionar”.
