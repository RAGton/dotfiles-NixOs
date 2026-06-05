# AGENTS.md — Kryonix

Contrato cross-tool para agentes de IA (Claude Code, Codex, Cursor, etc.) no repositório Kryonix.
Esta é a constituição curta; detalhes operacionais ficam nas skills `.claude/skills/`.

## Princípios
1. Código ativo é a fonte de verdade final. Não documente como pronto o que não existe.
2. Menor mudança segura. Refator profundo entra como série de PRs pequenos.
3. Declarativo até o fim (filosofia NixOS): nada de estado imperativo escondido.
4. Rollback sempre disponível: geração anterior + `git revert` devem reverter qualquer passo.

## Segurança (inviolável)
- Nunca commitar/embutir: `KRYONIX_BRAIN_KEY`, tokens, chaves SSH/GPG, `.env`, auth Tailscale.
- Secrets em runtime via `/etc/kryonix/brain.env` (modo restrito, gitignored) ou sops-nix/agenix.
- Nada de secret em `.nix`, `flake.nix`, docs, logs de CI ou `/nix/store`.

## Definição de Pronto (DoD)
- `git status` limpo (ou diffs justificados) e submodules sincronizados.
- `nix flake check --keep-going` passando.
- Build do(s) host(s) afetado(s) passando (toplevel) + Home Manager quando tocado.
- `kryonix test`/`boot` antes de `switch`. Sem traceback no CLI.
- Entrega com Plano / Diff / Teste / Risco / Rollback.

## Onde mexer
- Composição: `flake.nix`, `flake/**`     - Host: `hosts/<h>/`
- Módulo reutilizável: `modules/` ou `features/`   - Papel: `profiles/`
- Pacote/CLI: `packages/<comp>/`           - Overlay/patch: `overlays/`
- Desktop base: `desktop/hyprland/{system.nix,core/}`  - Shell/rice: `desktop/hyprland/caelestia/`

## Arquivos sensíveis (cuidado redobrado)
`flake.nix`, `flake.lock`, `hosts/*/hardware-configuration.nix`, `hosts/*/disks.nix`,
`modules/nixos/installer/*`, `packages/kryonix-cli*`, `.github/workflows/*`.

## Documentação Canônica e Memória IA
- Índice: `docs/README.md`
- O que é real: `docs/CURRENT_STATE.md`
- Contexto de Agente: `docs/ai/PROJECT_CONTEXT.md`
- Mapa Seguro: `docs/ai/PROJECT_INDEX.md`
- Regras MCP: `docs/mcp/SECURITY.md`
- Skills de IA: `.agents/skills/**`
