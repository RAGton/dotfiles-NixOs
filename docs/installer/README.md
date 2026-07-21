# Kryonix Installer

O Kryonix Installer é a stack responsável por transformar a imagem Live ISO em uma máquina downstream 100% gerenciada pelo Flake.

## Arquitetura
A stack é implementada primariamente em Rust. O backend Axum + UI Vite/React do installer vivem em repo próprio (`github:RAGton/kryxd`) e são consumidos pelo motor como flake input — derivação acessível via `pkgs.kryxd`. Os auxiliares `packages/kryonix-hardware-probe` e `packages/kryonix-disk-planner` continuam no motor, junto com scripts bash TUI em `modules/nixos/installer/`.

1. **Hardware Probe:** Identifica discos, UEFI/BIOS e rede.
2. **Disk Planner:** Gera o layout de partição (`disks.nix` format via Disko).
3. **Backend/Executor:** Roda formatação, clona o repositório, aplica o flake e injeta o bootloader.
4. **Front-End:** TUI (Terminal User Interface) atual ou Web-Kiosk (Roadmap).

## Links
- [Estado Atual](CURRENT_STATE.md)
- [Status do End-to-End Test](E2E.md)
- [Roadmap](ROADMAP.md)
