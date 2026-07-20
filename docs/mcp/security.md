# Segurança MCP

## Ameaças cobertas

### Escrita acidental ou induzida

Os servidores upstream de filesystem e Git possuem ferramentas mutantes. O
Kryonix os executa em `bubblewrap` com:

- `--unshare-all`: sem rede e namespaces separados;
- `--clearenv`: tokens e secrets do processo pai não são herdados;
- `/nix/store` montado read-only;
- somente raízes/repositórios da allowlist em `--ro-bind`;
- `$HOME`, cache e `/tmp` efêmeros dentro do sandbox;
- nenhum bind de `/`, `/etc`, `/home` ou `/run` do host.

O servidor pode anunciar uma ferramenta de escrita, mas uma tentativa contra o
repo ou Vault deve receber erro de filesystem read-only.

O wrapper de documentação NixOS é a exceção de rede: aplica `--share-net`, mas
continua sem mounts do host e sem herdar o ambiente do cliente.

### Path traversal

- todas as entradas devem ser absolutas;
- `/` é proibido;
- allowlist vazia é proibida quando a feature está habilitada;
- o dispatcher Git resolve o caminho real e exige igualdade exata com uma
  entrada da allowlist;
- cada processo Git enxerga apenas o repositório selecionado.

Essas proteções também limitam o impacto de falhas conhecidas no servidor Git
upstream. A versão continua pinada pelo `flake.lock`; atualizações devem ser
revisadas, não feitas implicitamente.

### Exposição de secrets

- nunca commitar `.mcp.json`, `.env`, tokens ou chaves;
- nunca registrar tokens em `.mcp.example.json`;
- filesystem, Git e sequential-thinking não recebem o ambiente do cliente;
- Brain remoto recebe secrets somente no Glacier, fora do repositório;
- não montar diretórios com secrets como raízes MCP.

### Poluição de `stdout`

MCP usa JSON-RPC em `stdout`. Logs devem ir para `stderr`. O teste de runtime
deve fazer handshake e `tools/list`, não apenas verificar que o processo abriu.

## O que não é barreira de segurança

- instrução no prompt;
- nome `readonly` no config;
- `readOnlyHint` informado pelo servidor;
- limitar o path sem mount read-only;
- executar como usuário comum sem sandbox;
- documentação dizendo que escrita está desabilitada.

## Regras obrigatórias

1. Registrar os wrappers `kryonix-mcp-*`, nunca os binários upstream diretamente.
2. Manter transportes locais em `stdio`.
3. Não habilitar GitHub/Fetch/Memory por padrão.
4. Não executar MCP como root.
5. Não montar `/`, `/etc`, `/root`, home completo ou diretórios de secrets.
6. Build/test antes de `switch`.
7. Tratar o Brain remoto como PARTIAL até prova no Glacier.

## Gates de validação

```bash
# Avaliação/build
nix flake check --keep-going

# Config local, quando existir
kryonix mcp check

# Higiene do diff
git diff --check
git diff | rg -n "api[_-]?key|token|secret|password|passwd|bearer|authorization|private|id_ed25519" -i || true
```

Além disso, executar provas negativas de escrita e de caminho fora da
allowlist. Falha em qualquer uma deixa o estado BROKEN; ausência de prova no
host deixa o estado UNKNOWN/PARTIAL.

## Riscos restantes

- o catálogo upstream ainda mostra ferramentas mutantes, embora o kernel negue
  escrita nos mounts;
- não há proxy de truncamento/paginação obrigatório para respostas grandes;
- `bubblewrap` depende de user namespaces disponíveis no host;
- o Brain por SSH tem superfície e ciclo de validação próprios.

## Rollback

Desabilitar as opções `kryonix.features.mcp.*`, fazer build do host e só então
ativar a geração anterior. Os wrappers são opt-in e não alteram dados.
