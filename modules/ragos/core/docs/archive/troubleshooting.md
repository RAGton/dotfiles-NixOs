# Troubleshooting

Status: archived  
Scope: Checklist antigo de troubleshooting substituido pelo runbook atual

## Checklist rápido
```
- [x] Imagem ativa em `/srv/data/images/current`?
- [x] Checksum no `manifest.json` confere?
- [x] `ragc doctor` reporta OK?
- [x] Nginx servindo `/netboot/current/bzImage`?
- [x] NFS exportado? (`showmount -e`)
- [x] Cliente recebe IP?
```

## Cliente não inicia o iPXE (TFTP)

1. **BIOS/UEFI**: O boot por rede (PXE) está habilitado?
2. **IP**: O cliente recebe IP? (ver `journalctl -u dnsmasq`)
3. **TFTP**: O arquivo `/srv/tftp/EFI/BOOT/BOOTX64.EFI` existe e tem permissão de leitura?
4. **Logs**: `journalctl -u dnsmasq -f` mostra o envio do arquivo?

## iPXE carrega mas falha ao buscar script (HTTP)

1. **URL**: Tente baixar o script no servidor: `curl http://localhost:8080/boot.ipxe`
2. **Nginx**: O serviço está rodando? `systemctl status nginx`
3. **Firewall**: A porta HTTP (padrão 8080) está aberta? `ragos status` (checa disponibilidade) ou `ufw status` / `iptables -L`.

## Kernel inicia mas trava no mount (NFS)

1. **Exports**: O NFS está exportando os caminhos? `showmount -e localhost`
2. **Rede**: O initrd recebeu IP? (Deve aparecer `ip=dhcp` nos logs do kernel na tela)
3. **Links**: O symlink `/srv/http/netboot` aponta para `/srv/data/images`?
4. **Permissões**: O diretório `/srv/data/images/current` é acessível pelo usuário do NFS?

---

## Build do cliente falha

**Sintomas:** `ragc switch` aborta no `nix build`.

**Verificar:**
```bash
# Build manual com log completo
nix build --impure .#nixosConfigurations.ragos-client.config.system.build.toplevel -v

# Checar flake.nix por erros de sintaxe
nix flake check --impure
```

**Causas comuns:**
- Parâmetros inválidos em `ragosParams` (falha da validação `_check`)
- Módulo com erro de sintaxe Nix
- Falta de memória/disco durante o build

---

## Login não funciona no cliente

**Sintomas:** SDDM inicia mas senha inválida.

**Verificar:**
```bash
# Conferir hash declarado no runtime do host
sudo grep adminHashedPassword /var/lib/ragos/runtime/params.nix

# Conferir hash efetivamente publicado no cliente
system_path=$(sed -n 's/.*"system_path": "\\([^"]*\\)".*/\\1/p' /srv/data/images/current/manifest.json)
users_json=$(nix-store -q --references "$system_path" | grep 'users-groups.json$' | head -n1)
tr '{' '\\n' < "$users_json" | grep '"name":"rag"'
```

**Causas comuns:**
- `ragc switch` executado fora do repositório operacional
- hash alterado no runtime e não republicado no cliente
- `users.mutableUsers = false` — senha do sistema é sempre a do hash declarado
- ausência de `/srv/data/home/<usuario>` quando `pam_mount` está ativo

---

## /home não persistente entre reboots

**Sintomas:** arquivos do usuário somem após reboot.

**Verificar:**
```bash
# /home está montado via NFS?
mount | grep home

# Exportação NFS inclui rw?
cat /etc/exports
```

**Causas comuns:**
- `/home` sendo montado como tmpfs em vez de NFS
- Falta opção `rw` na exportação NFS
