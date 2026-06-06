# Repository Map - Kryonix 🧊⚡

## Estrutura Crítica

- `flake.nix`: Ponto de entrada do sistema.
- `packages/kryonix-cli/`:
    - `main.sh`: Lógica de execução e parsing.
    - `registry.sh`: **Fonte única de verdade operacional** (Comandos, Riscos, Metadados).
- `hosts/`:
    - `glacier/`: Configuração do servidor IA (Ollama, Brain, GPU).
    - `inspiron/`: Configuração da workstation (Hyprland, Caelestia).
- `.context/`: Estado volátil e decisões de curto prazo.
- `.ai/`: Habilidades e governança de IA.
    - `skills/`: Runbooks acionáveis.
- `docs/`:
    - `agents/`: Governança de agentes (inclui `AGENTS.md` como mandato).
    - `cli/`: Documentação técnica da interface.
    - `SHORTCUTS.md`: Atalhos de teclado Hyprland.

## Fluxo de Verdade
1. **Código** (Flakes/Registry) > 2. **Context** (.context/) > 3. **Docs** (docs/) > 4. **Memory** (Vault/Logs).
