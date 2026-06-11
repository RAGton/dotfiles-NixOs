# Runbook — Kryonix Installer E2E via libvirt

## VM padrão

```bash
VM_NAME="kryonix-debug-installer"
ISO="/tmp/kryonix-installer-final-iso/iso/kryonix.iso"
DISK="/var/lib/libvirt/images/${VM_NAME}.qcow2"
```

## Descobrir IP

```bash
sudo virsh net-dhcp-leases default
sudo virsh domifaddr "$VM_NAME" || true
ip neigh show dev virbr0 || true
```

## Testar RemoteAccess

```bash
VM_IP="<IP_DA_VM>"

ping -c 2 "$VM_IP"
nc -vz -w 2 "$VM_IP" 8080
curl -s --connect-timeout 2 --max-time 5 "http://${VM_IP}:8080/network/status" | jq .
```

## Trocar ISO sem recriar VM

```bash
sudo virsh destroy "$VM_NAME" 2>/dev/null || true
sudo virsh domblklist "$VM_NAME"
sudo virsh change-media "$VM_NAME" sda "$ISO" --force
sudo virsh start "$VM_NAME"
```

## Resetar disco sem recriar VM

```bash
sudo virsh destroy "$VM_NAME" 2>/dev/null || true
sudo rm -f "$DISK"
sudo qemu-img create -f qcow2 "$DISK" 40G
sudo virsh start "$VM_NAME"
```

## Dados de teste

```txt
Hostname: kryonix-e2e
Usuário: tester
Senha: KryonixLab123!
Rede: DHCP
Perfil: desktop ou development
Disco: /dev/vda
Layout: btrfs-simple
```

## Critério de sucesso

* UI abre.
* IP real aparece.
* /network/status retorna JSON.
* dry-run passa.
* install chega ao final.
* VM boota pelo disco.
* `/etc/kryonix` existe.
* `/etc/kryonixos` existe.
* flake gerado é válido.
