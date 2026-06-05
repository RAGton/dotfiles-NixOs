# Estado Atual do Instalador

*Status: Parcial (🚧)*

O motor de instalação foi refatorado para uma arquitetura Cliente-Servidor local escrita em Rust, mas ainda não completou com sucesso todos os gates de teste End-to-End no hardware alvo sem intervenção manual.

## O Que Está Pronto
- Construção da ISO via `flake.nix`.
- Boot inicial em UEFI e Legacy (via systemd-boot e GRUB fallback).
- Ferramenta TUI primária (`kryonix-install-tui.sh`).
- Backend em Rust (geração do arquivo `.nix` do disko e chamadas `nixos-install`).
- Injeção da chave e repositório downstream após a formatação.

## O Que Falha (Problemas Conhecidos)
- Kernel Panic intermitente ao finalizar a injeção do Flake em VMs de teste devido à gerência de EFI variables.
- Boot sem ISO (O primeiro boot após install às vezes perde referência do GRUB EFI).
- Seleção de Wi-Fi pela TUI está rudimentar.
