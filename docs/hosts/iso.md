# Host: ISO (Instalador)

Este documento descreve o papel do host **ISO** na arquitetura Kryonix.

## Função
A ISO é o **único host implementado puramente no Upstream** (`/etc/kryonix`). Ela serve como ambiente live inicial para particionamento, detecção de hardware e formatação via TUI/Web, possibilitando o clone do repositório Downstream para criação de um novo Host no sistema de arquivos.

## Onde vive o código real
As configurações e módulos ficam em:
- `hosts/iso/default.nix` (A própria amarração da imagem ISO).
- `modules/nixos/installer/` (A lógica e scripts de particionamento e front-ends TUI).

## Validações e Build
Você gera a ISO do instalador puramente via `nix build` no upstream:

```bash
nix build .#nixosConfigurations.iso.config.system.build.isoImage
```
Ou usando as actions nativas no CI.

## O que está implementado vs Roadmap
- Ambiente Live Básico (tty1 autologin): Implementado.
- Scripts TUI Base: Implementado (`kryonix-install-tui.sh`).
- Backend em Rust Completo (Probe → Planner → Install): Parcial (Backend feito, test-run ainda quebra em ambientes específicos).
- Ambiente Web-Kiosk: Implementado o modo, porém sem o Front-end gráfico concluído (ROADMAP).
