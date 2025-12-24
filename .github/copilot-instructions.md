# Copilot Instructions for AI Coding Agents

## Project Overview
This repository manages NixOS and nix-darwin configurations for multiple machines using a modular, declarative approach. It leverages Nix flakes, Home Manager, and platform-specific modules for both Linux and macOS. The structure is designed for reproducibility, portability, and ease of customization.

## Key Architectural Patterns
- **Flake-based**: All configuration is rooted in `flake.nix`, which defines system and user modules, overlays, and input sources.
- **Modularization**: System (`modules/nixos/`), user (`modules/home-manager/`), and Darwin (`modules/darwin/`) modules are separated for clarity and reuse.
- **Home Manager**: User environments are managed declaratively via Home Manager modules, with per-user configs in `home/` and reusable logic in `modules/home-manager/`.
- **Host-specific**: Each machine has a config in `hosts/` (for system) and `home/` (for user), importing relevant modules.
- **Custom Scripts**: Utility scripts are in `modules/home-manager/scripts/bin/` and deployed to `~/.local/bin`.

## Developer Workflows
- **Build/Apply System**: Use `nixos-rebuild switch --flake .#hostname` for system changes, or `home-manager switch --flake .#user@hostname` for user changes.
- **Testing**: No automated tests; validate by applying configs and checking system/user state.
- **Script Usage**: Custom scripts (e.g., `asg-getter`, `konfig-updater`, `ocr`) require dependencies (see script headers) and are invoked directly from the shell.
- **Kubernetes/AWS**: Use `krew` plugins and scripts for cluster management. Zsh aliases and functions (see `programs/zsh/default.nix`) streamline kubectl and AWS CLI usage.

## Project-Specific Conventions
- **Theming**: Catppuccin theme is applied globally (see `catppuccin` input and related modules).
- **Desktop Rules**: Window assignment and hotkeys are managed declaratively (see `desktop/kde/default.nix` and `programs/aerospace/default.nix`).
- **Service Management**: Services like `easyeffects`, `swaync`, and `waybar` are configured via Home Manager modules.
- **Aliases/Shortcuts**: Extensive Zsh aliases for kubectl, git, and navigation (see `programs/zsh/default.nix`).
- **Krew Plugins**: Managed in `programs/krew/default.nix` and auto-installed/updated on activation.

## Integration Points
- **External Inputs**: Flake inputs include upstream Nixpkgs, Home Manager, hardware modules, and theming overlays.
- **Cross-Component**: System and user modules communicate via imports and shared variables (e.g., wallpaper, user info).
- **Platform Detection**: Many modules use `stdenv.isDarwin` to branch logic for macOS vs Linux.

# Copilot Instructions for AI Coding Agents

**Visão rápida**: Este repositório gerencia configurações Nix (NixOS + home-manager) via flakes, com módulos organizados por host, usuário e desktop.

**Arquitetura (onde olhar primeiro)**
- `flake.nix`: ponto de entrada — define hosts, entradas e overlays.
- `hosts/`: configurações do sistema por hostname (ex.: [hosts/inspiron/default.nix](hosts/inspiron/default.nix)).
- `home/`: configurações por usuário+host (ex.: [home/rag/inspiron/default.nix](home/rag/inspiron/default.nix)).
- `modules/home-manager/` e `modules/nixos/`: lógica reutilizável e agrupamentos (programas, serviços, scripts).
- `modules/home-manager/scripts/bin/`: scripts utilitários (ver shebang e permissões antes de alterar).

**Fluxos de trabalho essenciais**
- Aplicar mudanças no sistema:

	```bash
	sudo nixos-rebuild switch --flake .#<hostname>
	```

- Aplicar mudanças do usuário (Home Manager):

	```bash
	home-manager switch --flake .#<user>@<hostname>
	```

- Validação: não há testes automatizados — valide aplicando as flakes e verificando serviços/arquivos gerados.

**Convenções do projeto**
- Hosts nomeados em `hosts/<hostname>/` e configurações de usuário em `home/<user>/<hostname>/`.
- Pacotes globais: editar `modules/home-manager/common/default.nix` (campo `home.packages`).
- Overlays globais: `overlays/default.nix`.
- Plataformas: use `stdenv.isDarwin` para ramificações macOS vs Linux.
- Temas/desktop: catppuccin e módulos específicos em `modules/*/desktop/*` (ex.: KDE, Hyprland).

**Integrações e dependências externas**
- Flake inputs: Nixpkgs, Home Manager e outros overlays (ver `flake.nix` para a lista completa).
- Krew / kubectl / AWS: plugins e aliases são gerenciados por `programs/krew` e `programs/zsh`.

**Padrões de edição e PRs**
- Para adicionar um pacote ao ambiente do usuário: atualizar `modules/home-manager/common/default.nix` e testar com `home-manager switch`.
- Para alterar comportamento de host: modificar `hosts/<hostname>/default.nix` e rodar `nixos-rebuild switch --flake .#<hostname>`.
- Scripts novos: colocar em `modules/home-manager/scripts/bin/`, garantir shebang e `chmod +x`.

**Exemplos rápidos (onde tocar)**
- Customizar KDE: [modules/home-manager/desktop/kde/default.nix](modules/home-manager/desktop/kde/default.nix)
- Scripts utilitários: [modules/home-manager/scripts/bin/](modules/home-manager/scripts/bin/)
- Overlays: [overlays/default.nix](overlays/default.nix)

Se algo não for óbvio (dependências ausentes, comportamento de módulo), abra uma PR com uma descrição curta e testes manuais demonstrando `nixos-rebuild` / `home-manager switch` usados para validação.

---
Se quiser, eu posso ajustar esta versão para incluir exemplos de comandos reais do host `inspiron` ou expandir uma seção sobre como adicionar novos módulos.
