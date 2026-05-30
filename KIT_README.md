# Kryonix — Kit de Governança Claude Code

Kit no padrão oficial do Claude Code (CLAUDE.md + .claude/skills + commands + agents +
settings.json) para conduzir o refactor do Kryonix em Meta-Distro NixOS, fase a fase.

## Como instalar (na raiz do repo Kryonix)
1. Faça backup do que existe hoje:
   `mkdir -p .backup-kit && mv CLAUDE.md AGENTS.md .claude .backup-kit/ 2>/dev/null || true`
2. Copie o conteúdo deste ZIP para a raiz do repositório (mantendo a estrutura):
   `CLAUDE.md`, `AGENTS.md`, `.claude/`, `specs/`.
3. (Opcional) Ignore overrides pessoais:
   `echo ".claude/settings.local.json" >> .gitignore`
4. Abra o repo com `claude` (Claude Code). Rode `/memory` para confirmar que o CLAUDE.md carregou
   e `/agents` para ver os subagents. Skills aparecem automaticamente.

## Sobre apagar `skills/` e `claude.md` antigos
- Este kit usa `.claude/skills/` (com S, dentro de .claude). Se você tem uma pasta `skills/`
  na raiz ou um `claude.md`/`CLAUDE.md` antigo, eles foram para `.backup-kit/` no passo 1.
- Só apague o backup depois de validar que o kit novo funciona:
  `rm -rf .backup-kit` (faça isso por último, com git limpo).

## Como usar (fluxo recomendado)
1. **Auditoria**: peça "audite o repositório" → dispara a skill `kryonix-audit` (read-only).
2. **Planejar**: `/spec 01-flake` (ou edite as specs em `specs/`). Use plan mode (Shift+Tab).
3. **Executar uma fase**: peça "trabalhe na Fase 1" → skill `phase1-flake-modular`.
   As fases: phase1-flake-modular, phase2-packages, phase3-cachix, phase4-desktop.
4. **Validar**: `/nix-rebuild inspiron` (skill manual; nunca faz switch sozinha).
5. **Revisar**: o subagent `nix-reviewer` roda proativamente após edições .nix.
6. **Entregar**: `/entrega` monta o bloco Plano/Diff/Teste/Risco/Rollback.

## O que é o quê
| Arquivo | Papel | Quem invoca |
|---|---|---|
| `CLAUDE.md` | Memória de projeto (fatos sempre presentes) | Carregado automático |
| `AGENTS.md` | Constituição cross-tool (importada pelo CLAUDE.md) | Carregado via @import |
| `.claude/skills/kryonix-audit` | Auditoria estrutural | Claude (automático) |
| `.claude/skills/nix-rebuild` | Validação/teste seguro | Você (`/nix-rebuild`) |
| `.claude/skills/phase1..4` | Execução das fases do refactor | Claude (automático) |
| `.claude/agents/nix-reviewer` | Revisão imparcial (contexto isolado, opus) | Delegação automática |
| `.claude/agents/nix-debugger` | Depuração de erros Nix | Delegação automática |
| `.claude/commands/spec` | Cria spec em specs/ | Você (`/spec`) |
| `.claude/commands/entrega` | Bloco de entrega VIBECODE | Você (`/entrega`) |
| `.claude/rules/nix-modules` | Regras path-scoped p/ *.nix | Automático ao tocar .nix |
| `.claude/settings.json` | Permissões (deny secrets, ask switch/push) | Cliente (não o modelo) |
| `specs/*.md` | Fonte de verdade de cada fase | Você + Claude |

## Princípios embutidos (VIBECODE)
Não alucinar estado · secrets fora do Nix Store · migração incremental (1 PR por item) ·
rollback sempre possível · `nix flake check` antes de commit · `test`/`boot` antes de `switch`.

## Nota de manutenção
O Claude Code evolui rápido. `disable-model-invocation`, `memory:` em subagents e regras
path-scoped exigem versões recentes. Confira `claude --version` e a doc oficial se algo não carregar.
