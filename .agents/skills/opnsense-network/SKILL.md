---
name: opnsense-network
description: Administração de firewall e rede com OPNsense — regras de firewall, NAT, VLANs, VPN (WireGuard, OpenVPN, IPsec), DHCP, DNS (Unbound), HAProxy, IDS/IPS (Suricata), plugins, API REST do OPNsense, automação e integração com Proxmox e infraestrutura homelab/enterprise. Use sempre que o usuário mencionar OPNsense, pfSense, firewall, regras de firewall, NAT, WireGuard, VPN, VLAN em roteador, Unbound DNS, HAProxy no OPNsense, Suricata IDS, ou qualquer configuração de rede/segurança em OPNsense.
---

# OPNsense — Firewall & Rede

## Arquitetura típica homelab

```
Internet (WAN)
    │
[OPNsense]
    ├── LAN (vmbr0) — 192.168.1.0/24    — dispositivos gerais
    ├── VLAN 10    — 10.10.10.0/24      — servidores/Proxmox
    ├── VLAN 20    — 10.20.0.0/24       — IoT isolado
    └── VLAN 30    — 10.30.0.0/24       — guest WiFi
```

## API REST do OPNsense

```python
import requests

BASE = "https://opnsense.local/api"
AUTH = ("chave_api", "segredo_api")  # System > Access > Users > API Keys

# Listar regras de firewall
r = requests.get(f"{BASE}/firewall/filter/searchRule",
                 auth=AUTH, verify=False)
rules = r.json()

# Aplicar mudanças pendentes
requests.post(f"{BASE}/firewall/filter/apply", auth=AUTH, verify=False)

# Buscar leases DHCP
leases = requests.get(f"{BASE}/dhcpv4/leases/searchLease",
                      auth=AUTH, verify=False).json()
```

## Regras de firewall — lógica

```
Regras são avaliadas de CIMA para BAIXO, primeira que bate vence.

Estrutura padrão de uma regra:
  Action:    Pass / Block / Reject
  Interface: LAN / WAN / VLAN10
  Protocol:  TCP / UDP / ICMP / any
  Source:    rede ou host de origem
  Dest:      rede ou host de destino
  Port:      porta destino

Boas práticas:
  1. Block por padrão (default deny) em todas as interfaces
  2. Permitir apenas o necessário explicitamente
  3. Bloquear Inter-VLAN na origem, não no destino
  4. Log em regras críticas de bloqueio
```

## WireGuard VPN

```bash
# Gerar chave no cliente
wg genkey | tee privatekey | wg pubkey > publickey

# Configuração cliente (wg0.conf)
[Interface]
PrivateKey = <chave_privada_cliente>
Address = 10.0.0.2/24
DNS = 10.10.10.1

[Peer]
PublicKey = <chave_publica_opnsense>
Endpoint = meu.dominio.com:51820
AllowedIPs = 0.0.0.0/0  # full tunnel; ou 10.0.0.0/8 para split
PersistentKeepalive = 25
```

No OPNsense: VPN > WireGuard > Instances + Peers + habilitar, depois adicionar regra no firewall.

## HAProxy — reverse proxy + SSL

```
Frontend:
  Listen Address: 0.0.0.0:443 (HTTPS)
  SSL: Let's Encrypt cert
  ACL: hdr(host) == "app.dominio.com" → use backend_app

Backend:
  Server: 10.10.10.50:8080
  Health check: HTTP GET /health
```

Plugins necessários: `os-haproxy`, `os-acme-client`

## Unbound DNS — DNS local + bloqueio

```
# Em Services > Unbound DNS > Overrides
Host Override:
  Host: proxmox
  Domain: lan
  IP: 10.10.10.10

# Blocklist (DNSBL)
Services > Unbound DNS > Blocklists
  - Steven Black (ads + malware)
  - Hagezi Pro
```

## Suricata IDS/IPS

```
Modos:
  IDS = apenas detecta (não bloqueia) — bom para começar
  IPS = detecta e bloqueia — produção

Configuração inicial:
  1. Services > IDS > Administration > Enable
  2. Interface: WAN (e LANs se desejar)
  3. Download rulesets: ET Open (gratuito) ou ET Pro
  4. Policy: Default (balanced)
  5. Inspecionar alertas em Services > IDS > Alerts
```

## Comandos CLI (SSH no OPNsense)

```bash
# Status de interfaces
ifconfig

# Tabela de roteamento
netstat -rn

# Reiniciar serviço
/usr/local/etc/rc.d/haproxy restart

# Testar regra de firewall
pfctl -sr | grep <IP>

# Logs em tempo real
clog /var/log/filter.log | tail -f

# Flush estado de conexões
pfctl -F states
```

## VLAN — configuração básica

```
No OPNsense:
  1. Interfaces > Other Types > VLAN
     Parent: em0 (ou vtnet0)
     VLAN tag: 10
     Description: SERVIDORES

  2. Interfaces > Assignments → adicionar nova VLAN10
     Enable, IP estático: 10.10.10.1/24

  3. Services > DHCPv4 > [VLAN10]
     Range: 10.10.10.100 - 10.10.10.200

  4. Firewall > Rules > VLAN10
     Adicionar regras permitindo saída para internet
     Bloquear acesso de VLAN10 para LAN (isolamento)
```

## Referências adicionais
- **OpenVPN e IPsec**: ver [references/vpn-advanced.md](references/vpn-advanced.md)
- **Automação Ansible**: ver [references/ansible-opnsense.md](references/ansible-opnsense.md)
- **Hardening e segurança**: ver [references/hardening.md](references/hardening.md)
