# Memória Operacional Atual do Kryonix

Esta página serve como memória curta de estado vitalício para agentes que interagem de forma recorrente com o projeto.

*Versão Atual: v0.6.0-dev*

## Status do CI e Cachix
O CI (Cachix) está atualmente **VERDE** (operacional e compilando com sucesso). Qualquer quebra no build (via `nix flake check`) é tratada como criticidade máxima e deve ser revertida, não perpetuada.

## Comandos Permitidos e Proibidos (Agentes)
**Proibidos:**
- `git add .` ou `git commit -a` (Sempre use commits cirúrgicos).
- Modificar `flake.lock`.
- Rodar `nixos-rebuild switch` sem permissão explícita.
- Criar mocks de credenciais no repositório.

**Recomendados / Seguros:**
- `nix flake check --keep-going` (Sempre que alterar arquivos `.nix`).
- Inspecionar logs em `stderr` (via systemctl).
- Ler docs de `modules/`.

## Decisões Arquiteturais Recentes Relevantes (v0.6.0)
- **Kora/Hermes Aposentados:** As features de áudio e roteamento antigo não funcionam mais. O foco está no Caelestia interagindo com `Aura` (roteador de IA) e `LightRAG` diretamente.
- **RAG Local:** O Neo4j funciona apenas na rede Tailscale `100.64.0.0/10` sem senhas, usando porta `7687` e `7474`. O Host client não acessa, ele repassa pelo túnel.
- **MCP via Stdio:** Todo fluxo de MCP foi convertido para operar via `stdio`. Nenhuma chamada via HTTP ou SSE deve ser desenhada para novas integrações.

## Frentes Abertas
O trabalho primário agora é:
1. Fechar E2E Installer.
2. Ativar Servidores MCP seguros e read-only.
