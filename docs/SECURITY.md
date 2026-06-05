# Política de Segurança e Operações Seguras

Esta página define as regras invioláveis de segurança e operação do repositório Kryonix.

## Gestão de Secrets

- **NENHUM secret deve ser commitado** no repositório.
- Arquivos sensíveis detectáveis por padrão (ex: `*.env`, chaves SSH, API keys) são impedidos pelo `.gitleaks.toml` e workflow do GitHub Actions.
- **Onde vivem os secrets?** Em runtime, eles são carregados de `/etc/kryonix/*.env` com permissão restrita `0600`.
- Arquivos env conhecidos:
  - `brain.env` (API Keys do Brain e provedores externos)
  - `neo4j.env` (Credenciais de banco de dados)

## Sandboxing e Model Context Protocol (MCP)

As ferramentas de IA interagem com o Kryonix através de servidores MCP. A segurança desta camada é rigorosa:

1. **Restrição de Filesystem:** O MCP de filesystem começa como `read-only`. O acesso global a `/` é terminantemente proibido.
2. **Separação de Configuração:**
   - A configuração local (`.mcp.json`) é `.gitignore`'d e contém tokens de acesso reais.
   - A configuração versionada (`.mcp.example.json`) atua como template canônico sem secrets.
3. **Padrão de Comunicação:** Os servidores MCP devem comunicar apenas JSON-RPC limpo no `stdout`. Quaisquer logs ou warnings devem ir para o `stderr`.
4. **Bancos de Dados:** O acesso inicial do MCP ao Neo4j ou PostgreSQL é sempre `read-only`. Comandos destrutivos são bloqueados na raiz.

Detalhes completos de arquitetura MCP em: `docs/mcp/SECURITY.md`.

## Modificações no NixOS (Safe Changes)

Toda e qualquer mudança arquitetural ou de pacotes deve seguir o princípio do "Menor Dano Seguro" e ser passível de rollback:

- Validação estática: `nix flake check --keep-going`
- O `switch` para a nova configuração (`kryonixos-rebuild switch` ou `kryonix switch`) deve sempre poder ser revertido selecionando a geração anterior no GRUB.
- Evitar o comando `git add .`. Faça commits granulares e específicos, listando arquivos explicitamente para prevenir inclusão acidental de lixo ou secrets.
