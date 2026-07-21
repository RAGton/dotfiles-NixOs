# RagOS VE

**Atualizado em:** 2026-04-20

## Visão

RagOS VE é a edição de workstation e virtualização do **RagOS**. O projeto existe para operar uma máquina principal declarativa que sirva, ao mesmo tempo, como:

- desktop principal
- máquina gamer
- estação de estudo
- estação de desenvolvimento
- host pessoal de VMs
- base futura para ISOs instaláveis

## Princípios

- simplicidade operacional acima de hacks vistosos
- host real primeiro, engenharia futura depois
- branding consistente de boot a desktop
- KVM/libvirt como hypervisor principal
- Hyprland + DMS como desktop real do produto hoje

## Arquitetura de produto

O projeto hoje se organiza assim:

- `hosts/`: hardware, boot e papel de cada máquina
- `hosts/common/`: composição compartilhada entre hosts
- `modules/nixos/**`: base, programas, branding, rede, serviços
- `features/**`: capacidades opt-in como gaming, virtualização e desenvolvimento
- `profiles/**`: combinações reutilizáveis por papel
- `home/**`: experiência do usuário por host

## Host principal

O `glacier` é o host principal do RagOS VE neste momento. Ele concentra:

- tuning de workstation AMD + NVIDIA
- stack gamer
- stack de virtualização
- storage central para imagens, ISOs e backups
- branding principal do sistema

## Branding

O RagOS VE já padroniza:

- `Plymouth`
- `GRUB`
- `GDM`
- wallpaper do desktop
- `/etc/os-release`
- `/etc/issue`

Os assets vivem em `files/wallpaper/` e o branding do sistema é centralizado em `modules/nixos/branding/node/default.nix`.

## Direção futura

O objetivo não é virar uma distro genérica. A direção é manter o projeto como plataforma pessoal declarativa, mas madura o suficiente para gerar:

- ISOs de instalação do próprio RagOS VE
- provisionamento mais previsível para novos hosts
- operação diária mais simples via `node`

## Limites deliberados

- o layout real do `glacier` não deve ser reformatado por acidente
- `hosts/glacier/disks.nix` não é a fonte de verdade do host já instalado
- a plataforma prioriza sustentabilidade e clareza sobre abstrações excessivas
