# Índice do Projeto para Agentes

Use este mapa para navegar pela base de código de forma rápida e precisa. Nunca invente ou presuma pastas que não estão nesta lista.

## Caminhos Estratégicos (Upstream Engine - `/etc/kryonix`)
- `/etc/kryonix/flake.nix` → Ponto central. Usa NixOS 26.05 stable.
- `/etc/kryonix/flake/lib.nix` → Helper functions para montar instâncias Downstream.
- `/etc/kryonix/modules/nixos/services/brain.nix` → Core IA, define systemd services.
- `/etc/kryonix/packages/kryonix-brain-lightrag/` → Código Python da IA.
- `/etc/kryonix/packages/kryonix-cli/` → Ferramenta de linha de comando.
- **`github:RAGton/kryonix-installer`** (flake input externo, rev pinada em `flake.lock`) → Backend Axum (Rust) + UI Vite/React do Instalador. Acessível via `pkgs.kryonix-installer`. Para DEV local, clone em `/home/rocha/kryonix/kryonix-installer/` e use `--override-input kryonix-installer path:/home/rocha/kryonix/kryonix-installer`.
- `/etc/kryonix/desktop/hyprland/core/keybinds.nix` → Atalhos do Hyprland.
- `/etc/kryonix/.mcp.example.json` → Template MCP limpo.

## Caminhos Estratégicos (Downstream Hosts - `/etc/kryonixos`)
> *Você não tem acesso a esta pasta diretamente no repositório Upstream.*
- `/etc/kryonixos/flake.nix` → Define inputs e `.follows`.
- `/etc/kryonixos/hosts/glacier/` → Configuração de hardware do Server.
- `/etc/kryonixos/hosts/inspiron/` → Configuração de hardware do Client.
- `/etc/kryonixos/users/rocha/` → Instâncias Home Manager.

## Documentação Core
- `docs/README.md` → Índice Humano Principal.
- `docs/CURRENT_STATE.md` → O que está implementado de verdade.
- `docs/ROADMAP.md` → O que é futuro.
- `docs/ARCHITECTURE.md` → Arquitetura do Motor.
- `docs/mcp/SECURITY.md` → Segurança MCP e APIs.
