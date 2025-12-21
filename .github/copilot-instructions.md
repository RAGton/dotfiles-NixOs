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

## Examples
- To add a new package for all users: edit `modules/home-manager/common/default.nix` under `home.packages`.
- To customize KDE: edit `modules/home-manager/desktop/kde/default.nix`.
- To add a new script: place it in `modules/home-manager/scripts/bin/` and ensure it is executable.

## References
- See `README.md` for a high-level overview and module descriptions.
- Key files: `flake.nix`, `hosts/`, `home/`, `modules/`, `overlays/`, `README.md`.

---
If you are unsure about a workflow or convention, check the relevant module or script, or ask for clarification in a pull request.
