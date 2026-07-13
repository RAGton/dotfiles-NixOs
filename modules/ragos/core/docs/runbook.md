# Runbook Operacional

Status: canonical
Scope: operacao diaria, checagens e troubleshooting do ambiente RAGOS
Last reviewed: 2026-04-09

Este runbook descreve a operacao do ambiente RAGOS com foco em:

- servidor instalado;
- publicacao da imagem do cliente;
- inventario basico do parque;
- direcao operacional para Wake-on-LAN.

Quando houver divergencia entre atalho local e este runbook, prefira o runbook.

Para aceite de reinstalacao limpa e primeiro publish, use tambem [day0-acceptance.md](./day0-acceptance.md). O runbook descreve operacao diaria; o contrato Day-0 define o minimo que precisa funcionar logo apos reinstalar.

---

# 1. Pre-requisitos

- servidor RAGOS instalado e acessivel por SSH;
- checkout operacional em `/etc/ragos`;
- storage persistente montado em `/srv/data`;
- servicos de rede de boot ativos no servidor;
- pelo menos um cliente ja inventariado.

## Acesso ao srv-rag

Use SSH como caminho primario de operacao:

```bash
ssh <admin>@<ip-do-srv-rag>
```

Fallbacks suportados quando o acesso por rede ainda nao esta disponivel:

- console local em `tty1`;
- console serial em `ttyS0` quando o host/VM expuser UART classica;
- console serial em `hvc0` quando o hipervisor expuser console paravirtual;
- console serial em `ttyAMA0` quando o hardware expuser esse device.

Ordem de triagem para problema de acesso ao host:

1. confirmar SSH e firewall na porta `22`;
2. confirmar getty local em `tty1`;
3. confirmar se o ambiente atual expoe `ttyS0`, `hvc0` ou `ttyAMA0`;
4. so depois tratar senha, shell ou runtime de usuario.

---

# 2. Conceitos operacionais rapidos

## `ragos`

Opera o servidor.

## `ragc`

Opera a imagem do cliente.

## Inventario

E a base para:

- reservas DHCP;
- hostname unico;
- troubleshooting;
- futuro WOL;
- futura gestao do parque.

---

# 3. Primeiro deploy do servidor

```bash
ragos path
cd "$(ragos path)"
ragos switch
```

Fallback explicito:

```bash
sudo nixos-rebuild switch --flake /etc/ragos#srv-rag
```

Validar apos aplicar:

```bash
ragos status
systemctl status dnsmasq nginx nfs-server
```

---

# 4. Publicacao da imagem do cliente

Publicar nova imagem:

```bash
sudo ragc switch --channel generic
```

Rollback rapido:

```bash
sudo ragc rollback
```

Rollback para geracao especifica:

```bash
sudo ragc rollback v20260305-120000
```

Listar estado das geracoes:

```bash
ragc list
ragc doctor
```

GC conservador:

```bash
sudo ragc gc
```

---

# 5. Fluxo de boot esperado do cliente

Fluxo operacional resumido:

1. cliente recebe DHCP;
2. cliente chainloada iPXE;
3. `boot.ipxe` consulta o inventario por MAC via `by-mac/<mac>.ipxe`;
4. o inventario decide se aquele MAC chainloada `generic.ipxe`, `lab.ipxe` ou `rescue.ipxe`;
5. kernel + initrd sao carregados;
6. o contrato oficial deste ciclo e root por `/nix/store` via NFS + overlay;
7. `/home` e montado por NFSv4;
8. o usuario entra na sessao;
9. so depois do login real os setores compartilhados do usuario aparecem em `~/Setores/<grupo>`.

Se o cliente nao chega no login, a triagem deve comecar nesta ordem:

1. DHCP;
2. HTTP de boot;
3. artefatos publicados;
4. montagem de `/home`;
5. hook de setores em `~/Setores`;
6. sessao grafica.

## Validar home e setores apos login

No cliente, com uma sessao real ja aberta:

```bash
mount | grep ' /home/'
findmnt --target "/home/$USER"
findmnt --target "/home/$USER/Setores/<grupo>"
ls -la "/home/$USER/Setores"
```

Esperado:

- `/home/$USER` montado antes de qualquer setor;
- `~/Setores` presente dentro da home montada;
- apenas grupos/setores do usuario montados;
- ausencia de dependencia de `/mnt/groups`.

Roadmap: migracao para netboot/SquashFS permanece planejada, mas nao e contrato de operacao hoje.

---

# 6. Inventario minimo do parque

Cada cliente deve ter ao menos:

- hostname;
- MAC;
- IP reservado;
- observacao de local ou papel.

Exemplo conceitual:

```text
tc-01 | 52:54:00:64:10:11 | 192.168.100.110 | generic
tc-02 | 52:54:00:64:10:12 | 192.168.100.111 | lab
```

## Regras

- nao reutilizar hostname;
- nao operar cliente sem nome;
- nao depender de lembrar MAC de cabeca;
- nao manter mais de uma fonte conflitante sem plano de unificacao.

---

# 7. Adicionar cliente ao parque

## Etapa 1 -- registrar inventario

Registrar:

- MAC;
- hostname;
- IP reservado;
- local ou papel.

Nota operacional:

- o inventario decide para qual canal cada MAC aponta;
- `ragc` publica a geracao de cada canal e atualiza `current-generic`, `current-lab` ou `current-rescue`;
- mudar inventario nao publica cliente novo; publicar cliente novo nao altera inventario.

## Etapa 2 -- aplicar reserva DHCP

Exemplo conceitual:

```text
dhcp-host=52:54:00:64:10:11,set:known,set:chan-generic,set:hw-physical-generic,tc-01,192.168.100.110,infinite
dhcp-host=52:54:00:64:10:12,set:known,set:chan-lab,set:hw-physical-lab,tc-02,192.168.100.111,infinite
```

## Etapa 3 -- reaplicar servidor

```bash
sudo ragos-inventory-apply
```

## Etapa 4 -- validar lease

```bash
journalctl -u dnsmasq -n 100 --no-pager
```

---

# 8. Estado dos servicos

Verificar servicos principais:

```bash
ragos status
systemctl status dnsmasq nginx nfs-server
```

Validar HTTP de boot:

```bash
curl -I http://127.0.0.1:${HTTP_PORT:-8080}/boot.ipxe
curl -I http://127.0.0.1:${HTTP_PORT:-8080}/generic.ipxe
curl -I http://127.0.0.1:${HTTP_PORT:-8080}/lab.ipxe
```

Validar exports NFS:

```bash
exportfs -v
showmount -e localhost
ss -tnp | grep 2049
```

Validar espaco e montagem do tier de dados:

```bash
df -h /srv/data
mount | grep /srv/data
btrfs filesystem df /srv/data
```

---

# 9. Observabilidade base

Validar timers e coletor:

```bash
systemctl status ragos-metrics.timer ragos-metrics.service
sudo systemctl start ragos-metrics.service
```

Verificar arquivo de metricas:

```bash
sudo tail -n +1 /var/lib/node_exporter/textfile_collector/ragos.prom
```

Perguntas minimas que a observabilidade precisa responder:

- o servidor esta saudavel?
- a imagem atual existe e esta integra?
- o HTTP de boot responde?
- o storage esta enchendo?
- clientes estao pegando DHCP?

---

# 10. Wake-on-LAN -- direcao operacional

## Escopo

Wake-on-LAN deve ser operado pelo servidor via `ragos`.

Interface alvo minima:

```bash
ragos wol <hostname|mac>
```

## Estado nesta revisao

WOL ainda deve ser tratado como direcao operacional do projeto, nao como funcionalidade concluida, enquanto o comando nao existir no codigo.

## Regras

- operar por cliente inventariado;
- preferir hostname sobre digitacao manual de MAC;
- emitir a partir da interface LAN correta do servidor;
- registrar acao no journald;
- validar em hardware fisico compativel.

## Exemplo de saida desejavel

```text
[INFO] host=tc-01 mac=52:54:00:64:10:11 ip=192.168.100.110 iface=enp1s0
[INFO] sending magic packet to 192.168.100.255:9
[OK] packet sent
```

## O que verificar se nao funcionar

1. BIOS/UEFI com WOL habilitado;
2. ErP/Deep Sleep desativado quando necessario;
3. NIC compativel com wake;
4. cabo e link fisico ativos;
5. MAC correto no inventario;
6. pacote saindo da interface certa;
7. validacao feita em hardware real, nao so em VM.

---

# 11. Procedimentos rapidos de triagem

## Cliente nao pega DHCP

```bash
ip -br addr
sudo systemctl status dnsmasq
sudo journalctl -u dnsmasq -b --no-pager | tail -100
sudo cat /run/ragos-inventory/dnsmasq-hosts.conf
```

## Cliente nao baixa iPXE

```bash
sudo ls -l /srv/tftp/EFI/BOOT/BOOTX64.EFI
sudo journalctl -u dnsmasq -b --no-pager | tail -100
```

## Cliente trava no boot

```bash
ragc doctor
ragc list
ls -l /srv/data/images/current /srv/data/images/rescue
ls -l /srv/data/images/current-generic /srv/data/images/current-lab
curl -fsS http://127.0.0.1:8080/generic.ipxe
curl -fsS http://127.0.0.1:8080/lab.ipxe
curl -fsS http://127.0.0.1:8080/current.ipxe
curl -fsS http://127.0.0.1:8080/rescue.ipxe
```

## Cliente nao monta `/home`

```bash
showmount -e 127.0.0.1
exportfs -v
systemctl status nfs-server
findmnt /srv/data/home
```

## Cliente nao liga apos futuro WOL

Checar:

- inventario e MAC;
- suporte de hardware;
- BIOS/UEFI;
- broadcast/interface;
- energia em standby na NIC.

## Servidor aplica, mas parque fica inconsistente

Checar:

- integridade da geracao atual;
- `ragc doctor`;
- symlinks de `current` e `previous`;
- snapshots pre-GC;
- convergencia entre inventario e DHCP.

---

# 12. Restauracao e rollback

## Quando usar `ragc rollback`

Use quando:

- a nova imagem foi publicada;
- o storage esta integro;
- o problema esta na geracao ativa;
- a geracao anterior ainda existe.

## Quando usar restore por snapshot

Use quando:

- uma geracao sumiu indevidamente;
- `current` aponta para caminho quebrado;
- houve erro humano ou incidente no tier de dados.

Fluxo resumido:

1. localizar snapshot relevante;
2. restaurar a geracao;
3. reativar `current`;
4. rodar `ragc doctor`;
5. validar HTTP de boot.

---

# 13. Direcao imediata recomendada

A prioridade operacional correta hoje e:

1. alinhar documentacao com a arquitetura atual;
2. consolidar inventario declarativo;
3. implementar WOL em `ragos`;
4. integrar WOL ao runbook e a observabilidade;
5. endurecer allowlist e rede de boot.

Essa ordem evita construir ferramenta nova em cima de contrato torto.
