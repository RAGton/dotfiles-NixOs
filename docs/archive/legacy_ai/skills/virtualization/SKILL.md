---
name: virtualization
description: Gerencia virtualização KVM/libvirt nativa no glacier (kryonix) — criação e operação de VMs, storage em /srv/ragenterprise, prevenção de ações destrutivas em imagens e backups. Use quando a tarefa envolver VMs no glacier via libvirt, virt-manager, virsh, storage de VM, ou configuração de virtualização NixOS. Para Proxmox VE externo, usar proxmox-infra.
---

# Skill: Virtualization

## Escopo

Virtualização do Kryonix com foco em libvirt/KVM.

## Regras

- tratar `/srv/ragenterprise` como storage operacional do glacier (Btrfs @ragenterprise, subvols: vms, backups — path real no glacier, não no inspiron)
- evitar ações destrutivas em imagens, templates e backups
- separar hardware base do host e storage operacional do hypervisor
- não abrir escopo para outras stacks sem necessidade

## Prioridade

- segurança operacional
- clareza do layout
- mudanças reversíveis
