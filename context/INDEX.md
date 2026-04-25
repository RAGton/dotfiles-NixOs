# Contexto do Kryonix

Este diretório é a porta de entrada curta para agentes.
Use leitura progressiva, não varredura cega.

## Ordem recomendada

1. `AGENTS.md`
2. `context/INDEX.md`
3. skill relevante em `skills/**`
4. código real
5. web oficial apenas quando necessário

## Leitura mínima por tipo de tarefa

### Launcher / Caelestia / Hyprland

- `context/CURRENT_STATE.md`
- `context/ARCHITECTURE.md`
- `context/DECISIONS/ADR-0003-kryonix-menu-wayland.md`
- `context/DECISIONS/ADR-0004-winbox-xwayland.md`
- `desktop/hyprland/user.nix`
- `ai/kryonix-vault/05-Skills/refatoracao-segura/SKILL.md`
- `ai/kryonix-vault/05-Skills/analise-performance/SKILL.md`

### Host / Nix / implementação

- `context/CURRENT_STATE.md`
- `context/HOSTS/<host>.md`
- `context/RUNBOOKS/nix-host-validation.md`
- `skills/nix-host-implementation/SKILL.md`

### Obsidian / memória local

- `context/CURRENT_STATE.md`
- `context/RUNBOOKS/obsidian-vault-ops.md`
- `skills/obsidian-memory/SKILL.md`

### Release / changelog / fechamento

- `context/CURRENT_STATE.md`
- `context/RUNBOOKS/release-flow.md`
- `skills/release-engineering/SKILL.md`

## Mapa rápido

- `CURRENT_STATE.md`: estado atual curto e rastreável
- `ARCHITECTURE.md`: mapa de camadas do repo e da camada de contexto
- `HOSTS/`: notas operacionais por host
- `RUNBOOKS/`: operação e troubleshooting
- `DECISIONS/`: decisões arquiteturais ativas
- `INCIDENTS/`: falhas reais e resolução
- `SOURCES/official-sources.md`: links oficiais usados como base externa

## Regra de economia de contexto

- prefira arquivos curtos e indexados
- só aprofunde quando a tarefa pedir
- trate `ai/` como material histórico/experimental
- registre incidente ou decisão quando isso reduzir redescoberta futura
