# Rede

Status: canonical
Scope: rede de boot, DHCP, TFTP, HTTP, NFS e inventario de clientes
Last reviewed: 2026-04-09

## Modelo

O RAGOS assume uma LAN de boot controlada pelo `srv-rag`.

- `dnsmasq` entrega DHCP e TFTP;
- `nginx` entrega HTTP de boot;
- NFS atende `/home`;
- clientes desconhecidos nao devem receber boot util.

## Inventario como fonte de verdade

Parametros do host:

- `server/runtime/params.nix`

Inventario de clientes:

- `/etc/ragos-inventory/clients.nix`

O inventario deve sustentar:

- hostname;
- MAC;
- IP reservado;
- channel de operacao (`generic|lab|rescue`);
- releaseTrack compativel (`stable|pilot|rescue`) quando a camada nova estiver sendo usada;
- profile/target do cliente quando necessario para coerencia semantica;
- clientProfile compativel (`workstation|lab-workstation|hyperv-debug|rescue`) quando a camada nova estiver sendo usada;
- bootMethod (`ipxe` por default implicito; `uefi-http` apenas controlado; `uefi-https` reservado/futuro);
- hardwareClass (`physical-generic|physical-lab|hyperv|rescue`);
- allowlist;
- futura operacao de WOL.

## Compatibilidade semantica do inventario

O contrato atual do parque continua preso a `channel` + `hardwareClass` e ao
roteamento para `generic.ipxe`, `lab.ipxe` e `rescue.ipxe`.

Como camada compativel, o inventario agora tambem pode aceitar:

- `releaseTrack` como alias de `channel`;
- `clientProfile` como alias de `profile`;
- `bootMethod` como eixo semantico separado.

Nesta fase:

- inventario legado continua valido;
- inventario novo tambem e aceito;
- quando campos antigos e novos coexistirem, a coerencia e obrigatoria;
- `uefi-http` nao substitui o fluxo oficial atual;
- `uefi-https` continua reservado e deve falhar fechado ate haver prova real.

Detalhes da proposta e da migracao ficam em [boot-semantics.md](./boot-semantics.md).

## Portas operacionais

| Servico | Porta | Protocolo |
| --- | --- | --- |
| DHCP | 67 | UDP |
| TFTP | 69 | UDP |
| HTTP boot | 8080 por padrao | TCP |
| NFSv4 | 2049 | TCP |
| RPC bind | 111 | TCP/UDP |
| SSH | 22 | TCP |

## Inventario em vez de `dhcp-host` manual

Fluxo correto para cadastrar clientes:

1. editar `/etc/ragos-inventory/clients.nix`;
2. aplicar com `sudo ragos-inventory-apply`;
3. validar `/run/ragos-inventory/dnsmasq-hosts.conf`;
4. validar `/srv/http/by-mac/<mac>.ipxe`.

Formato conceitual:

```nix
[
  {
    mac = "00:15:5d:01:0c:03";
    hostname = "cliente-rag-01";
    ip = "192.168.100.110";
    channel = "generic";
    releaseTrack = "stable";
    clientProfile = "workstation";
    bootMethod = "ipxe";
    hardwareClass = "physical-generic";
  }
]
```

Linha `dhcp-host` resultante:

```text
dhcp-host=00:15:5d:01:0c:03,set:known,set:chan-generic,set:hw-physical-generic,cliente-rag-01,192.168.100.110,infinite
```

Rota HTTP por MAC resultante:

```text
/srv/http/by-mac/00:15:5d:01:0c:03.ipxe -> chain para /generic.ipxe
```

## Hostname unico por cliente

Regras:

- nao reutilizar hostname;
- nao deixar cliente sem identidade;
- nao operar o parque por memoria humana;
- nao manter mais de uma fonte divergente de MAC/IP/hostname.

## Wake-on-LAN na rede do parque

WOL ainda deve ser tratado como direcao operacional, nao como feature pronta, enquanto o comando nao existir.

Quando implementado, deve:

- usar inventario como lookup;
- sair pela interface LAN correta;
- usar broadcast controlado;
- nao ser exposto para WAN como atalho.

## Validacoes rapidas

```bash
ip -br addr
sudo journalctl -u dnsmasq -b --no-pager | tail -50
sudo cat /run/ragos-inventory/dnsmasq-hosts.conf
sudo cat /srv/http/by-mac/52:54:00:64:10:11.ipxe
curl -fsS http://127.0.0.1:8080/boot.ipxe
curl -fsS http://127.0.0.1:8080/generic.ipxe
curl -fsS http://127.0.0.1:8080/lab.ipxe
showmount -e 127.0.0.1
```
