# FOLDER_STRUCTURE

## Raiz

- `.github/`: instrucoes Copilot, prompts e CI.
- `.vscode/`: configuracao local do editor.
- `AGENTS.md`: contrato principal para agentes.
- `README.md`: visao publica do projeto (manual do engenheiro / fluxo de instalacao).
- `flake.nix`: entrada principal Nix (roteador fino).
- `flake.lock`: pins; nao alterar sem motivo.
- `SECURITY.md`: politica de reporte.

## Infra NixOS

- `hosts/`: hosts mantidos NESTE repo (motor) — apenas `common/`, `inspiron/` e `iso/`.
- `hosts/common/`: configuracao comum compartilhada.
- `hosts/inspiron/`: host de referencia (hardware-configuration.nix, disks.nix, default.nix).
- `hosts/iso/`: live/install ISO — unica `nixosConfiguration` exposta pelo flake do motor.
- Hosts pessoais (`glacier`, `inspiron-nina`, ...) NAO vivem aqui: ficam no repo
  downstream `/etc/kryonixos` (github:RAGton/Kryonixos), que consome este motor via
  `kryonix.url = git+file:///etc/kryonix`.
- `modules/nixos/`: modulos de sistema.
- `modules/kernel/`: kernel Zen.
- `modules/virtualization/`: rede/virtualizacao compartilhada.
- `features/`: capacidades opt-in.
- `profiles/`: composicoes por papel.
- `overlays/`: overrides de pacotes.
- `packages/`: pacotes/CLIs do projeto.
- `lib/`: helpers e opcoes.

## Usuario e desktop

- `modules/home-manager/`: modulos Home Manager reutilizaveis (a config Home Manager
  por usuario/host vive no downstream `/etc/kryonixos`, nao ha `home/` neste repo).
- `desktop/hyprland/`: configuracao Hyprland system/user.
- `desktop/hyprland/rice/`: Caelestia/DMS e arquivos de rice.
- `assets/`: assets estaticos usados pelo sistema (wallpaper, avatar, sddm, grub-theme).

## Contexto e documentacao

- `docs/`: documentacao humana e historica.
- `docs/ai/`: contexto curto para LLMs.

## Camadas de contexto de IA (topologia)

Quatro diretorios de contexto com papeis DISTINTOS — nao sao redundantes e nao
devem ser fundidos as cegas. Mover qualquer um exige mapeamento de dependencias.

- `AGENTS.md` (raiz): constituicao cross-tool. Ordem de leitura #1 para qualquer agente.
- `.ai/`: camada de conhecimento/memoria canonica. Vault Obsidian
  (`kryonix-vault/`, **git submodule**), prompts reutilizaveis, skills por
  dominio, `STATE.md`. Fonte de grounding do RAG/Brain.
  **Consumida em runtime pelo CLI** (`packages/kryonix-cli/services.sh` le
  `.ai/STATE.md`) — nao mover sem patch coordenado do CLI + submodule.
- `.agents/`: governanca multi-agente (Antigravity/Kora). Roles, workflows,
  checklists e prompts de orquestracao.
- `.claude/`: config do Claude Code (agents, commands, rules, skills, settings).
  Path exigido pela ferramenta — nao renomear.
- `.codex/`: config do Codex (agents, `config.toml` com MCP servers).
  Path exigido pela ferramenta — nao renomear.

Ordem de leitura recomendada: `AGENTS.md` -> `docs/` ->
`.ai/kryonix-vault/01-Canonical/` -> o prompt/skill/role relevante a tarefa.

## Diretorios que agentes devem evitar em varreduras

- `.git/`
- `node_modules/`
- `dist/`
- `build/`
- `target/`
- `result/`
- `.direnv/`
- `vendor/`
- caches em geral

## Observacao

Se a tarefa for especifica, leia primeiro o indice curto e o modulo relevante. Evite varredura cega do repo inteiro.
