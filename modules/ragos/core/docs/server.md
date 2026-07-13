# Servidor RAGOS

Status: canonical
Scope: composicao do srv-rag, runtime do host e servicos principais
Last reviewed: 2026-04-09

## Papel

O `srv-rag` concentra:

- rede de boot;
- inventario do parque;
- storage persistente;
- publicacao das imagens do cliente;
- observabilidade;
- operacao do host.

## Estrutura ativa

```text
server/
├── auth/
├── hardware/
├── network/
├── pxe/
├── roles/
├── runtime/
├── services/
├── default.nix
└── ragos-cli.nix
```

## Composicao

| Modulo | Responsabilidade |
| --- | --- |
| `server/default.nix` | composicao principal do host |
| `server/roles/base.nix` | usuario admin, SSH, CLI `ragos`, ferramentas base |
| `server/roles/services.nix` | `dnsmasq`, `nginx`, NFS e inventario externo |
| `server/services/boot.nix` | bootloader, sysctl e parametros do kernel |
| `server/services/networking.nix` | rede do host e firewall |
| `server/services/storage.nix` | `/srv/data`, TFTP, links HTTP e snapshots |
| `server/services/monitoring.nix` | metricas e observabilidade |
| `server/services/srv-layout.nix` | exposicao do repo em `/srv/ragos` |

## Runtime do host

O flake do servidor nao deve ler `installer/params.nix` como fonte principal.

O runtime real do host fica em:

- `/var/lib/ragos/runtime/params.nix`
- `/var/lib/ragos/runtime/hardware-configuration.nix`

O checkout operacional expoe compatibilidade via:

- `server/runtime/params.nix`
- `server/runtime/hardware-configuration.nix`

## Inventario externo

O cadastro de clientes nao fica no modulo Nix do servidor.

A fonte de verdade operacional e:

```text
/etc/ragos-inventory/clients.nix
```

Ela deve ser:

- validada por MAC, hostname e IP unicos;
- renderizada para `dnsmasq`;
- aplicada com `ragos-inventory-apply`.

Bootstrap:

```bash
sudo ./scripts/ops/migrate-ragos-inventory.sh
```

## Split-storage e dados do parque

O servidor deve separar:

- Tier 0: sistema do host;
- Tier 1: `/srv/data/home`, `/srv/data/images` e `/srv/data/snapshots`.

O tier de dados deve usar BTRFS.

## Wake-on-LAN

WOL faz parte da responsabilidade futura do servidor e do `ragos`.

Enquanto nao houver implementacao real, a documentacao deve trata-lo como direcao planejada e nao como capacidade entregue.

## Servicos criticos

```bash
systemctl status dnsmasq nginx nfs-server
systemctl status ragos-metrics.timer ragos-metrics.service
ragos status
ragc doctor
```

## Acesso ao host

O caminho primario de acesso ao `srv-rag` e SSH na porta `22`.

Fallbacks operacionais suportados:

- login local em `tty1`;
- login serial em `ttyS0` quando o host ou a VM expuser esse device;
- login serial em `hvc0` quando o hipervisor expuser console paravirtual;
- login serial em `ttyAMA0` quando o hardware expuser esse console.

O welcome interativo do RAGOS deve aparecer em SSH e tambem nesses consoles
locais/seriais, mas SSH continua sendo o caminho primario para operacao do host.

## Operacao basica

```bash
ragos path
ragos switch
ragos test
ragos rollback
ragos check
```
