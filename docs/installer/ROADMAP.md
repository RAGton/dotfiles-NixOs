# Roadmap do Instalador

Este documento mapeia o futuro da instalação e do Live USB do Kryonix.

## Curto Prazo (Estabilização Base)
- [ ] Corrigir o Kernel Panic no fim da injeção do Bootloader.
- [ ] Validar instalação completa E2E em hardware real (Inspiron), sem depender de VirtualBox/QEMU.
- [ ] Script automático de rollback caso falhe no meio do particionamento.

## Médio Prazo (Feature Selection)
- [ ] Opção na TUI para selecionar o Profile (Server AI, Base, Gaming).
- [ ] Detecção de Placa de Vídeo para injeção do módulo correto (`nvidia.nix` vs `amdgpu.nix`) antes do build.

## Longo Prazo (Web Kiosk)
- [ ] Finalizar o Front-end Web (React/Vue) para rodar sobre o modo `web-kiosk.nix` nativamente.
- [ ] API local (`kryxd-bin`) expondo endpoints WebSocket para progresso da formatação.
