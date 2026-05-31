---
name: proxmox-infra
description: External Proxmox VE infrastructure skill — for physical Proxmox servers outside the kryonix/glacier stack. Use for Proxmox VE clusters, LXC containers, Proxmox API, ZFS/Ceph storage, and Terraform/Ansible automation against a dedicated Proxmox host. For KVM/libvirt virtualization on glacier itself, use the virtualization skill instead.
---

# Proxmox VE — Infraestrutura

## Conceitos fundamentais
- **VMID**: identificador único de cada VM/CT (100-999999)
- **Node**: servidor físico no cluster
- **Storage**: `local-lvm` (rápido), `local` (ISO/templates), ZFS, Ceph (cluster)
- **Network**: `vmbr0` = bridge principal → VMs se conectam aqui

## CLI essencial (em qualquer node)

```bash
# Listar VMs e containers
qm list
pct list

# Criar VM a partir de template
qm clone 9000 101 --name minha-vm --full

# Iniciar / parar / status
qm start 101
qm stop 101
qm status 101

# Snapshot
qm snapshot 101 snap-antes-update --vmstate

# Rollback
qm rollback 101 snap-antes-update

# Console
qm terminal 101

# Containers LXC
pct create 200 local:vztmpl/debian-12-standard.tar.zst \
  --hostname meu-ct --memory 512 --storage local-lvm \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp

pct start 200
pct exec 200 -- bash
```

## API REST do Proxmox

```python
import requests, urllib3
urllib3.disable_warnings()

BASE = "https://proxmox.local:8006/api2/json"

# Autenticação
r = requests.post(f"{BASE}/access/ticket", verify=False, data={
    "username": "root@pam", "password": "senha"
})
ticket = r.json()["data"]["ticket"]
csrf = r.json()["data"]["CSRFPreventionToken"]

headers = {"CSRFPreventionToken": csrf}
cookies = {"PVEAuthCookie": ticket}

# Listar VMs do node
vms = requests.get(f"{BASE}/nodes/pve/qemu", headers=headers,
                   cookies=cookies, verify=False).json()

# Iniciar VM
requests.post(f"{BASE}/nodes/pve/qemu/101/status/start",
              headers=headers, cookies=cookies, verify=False)
```

## Terraform — Proxmox Provider

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.46"
    }
  }
}

provider "proxmox" {
  endpoint = "https://proxmox.local:8006/"
  username = "root@pam"
  password = var.proxmox_password
  insecure = true
}

resource "proxmox_virtual_environment_vm" "vm" {
  name      = "terraform-vm"
  node_name = "pve"
  vm_id     = 150

  clone {
    vm_id = 9000  # template ID
    full  = true
  }

  cpu { cores = 2 }
  memory { dedicated = 2048 }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  disk {
    datastore_id = "local-lvm"
    size         = 20
    interface    = "scsi0"
  }
}
```

## ZFS — operações comuns

```bash
# Status do pool
zpool status
zpool list

# Criar dataset
zfs create rpool/data/vms

# Snapshot
zfs snapshot rpool/data/vms@backup-$(date +%F)

# Listar snapshots
zfs list -t snapshot

# Rollback
zfs rollback rpool/data/vms@backup-2025-01-01

# Compressão e dedup
zfs set compression=lz4 rpool/data
```

## Backup com vzdump

```bash
# Backup de VM para storage
vzdump 101 --storage backup-nfs --mode snapshot --compress zstd

# Agendar via cron (ou pela GUI: Datacenter > Backup)
# Restore
qmrestore /var/lib/vz/dump/vzdump-qemu-101-*.vma.zst 102 \
  --storage local-lvm
```

## Rede — VLANs e bridges

```bash
# /etc/network/interfaces — adicionar VLAN 100
auto vmbr0.100
iface vmbr0.100 inet manual
  vlan-raw-device vmbr0

auto vmbr100
iface vmbr100 inet static
  address 10.100.0.1/24
  bridge-ports vmbr0.100
  bridge-stp off
  bridge-fd 0
```

## Referências adicionais
- **Cluster e HA**: ver [references/cluster-ha.md](references/cluster-ha.md)
- **Ceph storage**: ver [references/ceph.md](references/ceph.md)
- **Templates e cloud-init**: ver [references/templates-cloudinit.md](references/templates-cloudinit.md)
