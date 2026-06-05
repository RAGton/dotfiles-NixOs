# Glacier

**Atualizado em:** 2026-04-20

## Papel do host

`glacier` é o host principal do Kryonix para:

- workstation diária
- gaming
- virtualização com KVM/libvirt
- estudo e desenvolvimento

## Fonte de verdade do hardware

No host já instalado, a fonte de verdade é:

- `hosts/glacier/hardware-configuration.nix`

Esse arquivo reflete o estado real de:

- boot EFI
- root e home em Btrfs
- módulos de initrd
- kernel modules
- UUIDs reais

## O que não usar de forma destrutiva

No `glacier` atual, **não** use:

- `hosts/glacier/disks.nix`
- `disko`
- `format-*`
- `install-system`

Esse arquivo de discos fica reservado para fluxos de provisionamento e não representa o caminho operacional seguro do host instalado.

## Storage de virtualização

O storage operacional do host fica em:

- `/srv/ragenterprise`

Subpastas padronizadas:

- `/srv/ragenterprise/images`
- `/srv/ragenterprise/iso`
- `/srv/ragenterprise/templates`
- `/srv/ragenterprise/snippets`
- `/srv/ragenterprise/backups`

UUID usado para o disco extra atual:

- `479c1b04-5000-424d-90ae-f2438496711e`

Layout declarativo do disco extra:

- [hosts/glacier/ragenterprise-disko.nix](../hosts/glacier/ragenterprise-disko.nix)
- uma unica particao GPT/ext4 no disco SATA extra
- o UUID do filesystem e mantido para continuar montando `/srv/ragenterprise`
- use este arquivo apenas para o disco extra, nunca para o NVMe do sistema

Grupo operacional:

- `ragenterprise`

Usuários relevantes:

- `rocha` no grupo `ragenterprise`
- `rag` preservado declarativamente para compatibilidade com o host atual

## Perfil técnico

O host hoje está posicionado como:

- AMD Ryzen 7 9700X
- 16 GiB RAM DDR5
- NVIDIA RTX 4060
- kernel Zen com build local
- Hyprland + Caelestia
- GDM com branding Kryonix
- libvirt/KVM como hypervisor principal

## Rede e acesso preservados

Compatibilidade mantida a partir do host remoto atual:

- bridge `br0` sobre `enp6s0`
- `10.0.0.2/24`
- gateway `10.0.0.1`
- SSH em `2224`
- endpoint HTTPS simples em `rve.ragenterprise.com.br`

## Comandos recomendados

```sh
kryonix doctor
kryonix diff
kryonix test
kryonix boot
```

## Rebuild remoto seguro

Primeiro apenas verifique e faça o rebuild:

```sh
kryonix check --host glacier
kryonix rebuild --host glacier
```

Teste temporário:

```sh
kryonix test --host glacier
```

Switch só depois:

```sh
kryonix switch --host glacier
```
