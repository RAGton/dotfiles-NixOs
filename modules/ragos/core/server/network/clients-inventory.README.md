# RAGOS Client Inventory

Este arquivo e versionado em `server/network/`, mas e instalado no host como
`/etc/ragos-inventory/README.md`.

No diretorio operacional `/etc/ragos-inventory`, esse e o README da fonte
canonica do inventario de clientes do RAGOS.

## Arquivos

- `clients.nix`: lista declarativa de clientes autorizados
- `clients.template.nix`: exemplo copiado a partir de `server/network/clients-inventory.bootstrap.nix` para facilitar o primeiro preenchimento

## Formato

```nix
[
  {
    mac = "52:54:00:64:10:11";
    hostname = "tc-01";
    ip = "192.168.100.110";
    channel = "generic";
    releaseTrack = "stable";
    clientProfile = "workstation";
    bootMethod = "ipxe";
    hardwareClass = "physical-generic";
  }
  {
    mac = "52:54:00:64:10:12";
    hostname = "tc-02";
    ip = "192.168.100.111";
    channel = "lab";
    releaseTrack = "pilot";
    clientProfile = "lab-workstation";
    bootMethod = "ipxe";
    hardwareClass = "physical-lab";
  }
]
```

## Exemplo de uso rapido

```bash
sudo cp /etc/ragos-inventory/clients.template.nix /etc/ragos-inventory/clients.nix
sudo nano /etc/ragos-inventory/clients.nix
sudo ragos-inventory-apply
```

Cada entrada precisa ter:

- `mac`: MAC real da placa do cliente
- `hostname`: nome que o cliente vai receber por DHCP/PXE
- `ip`: IP fixo dentro da rede LAN/PXE do `srv-rag`

Campos opcionais recomendados para governanca de produto:

- `channel`: `generic | lab | rescue`
- `releaseTrack`: alias compativel de `channel` (`stable | pilot | rescue`)
- `profile`: alias legivel do target atual (`desktop-generic | desktop-lab | hyperv-debug | rescue-minimal`)
- `clientProfile`: alias compativel de `profile` (`workstation | lab-workstation | hyperv-debug | rescue`)
- `bootMethod`: `ipxe` por default implicito; `uefi-http` aceito como metadado/control path; `uefi-https` continua reservado e falha fechado ate haver prova real
- `hardwareClass`: `physical-generic | physical-lab | hyperv | rescue`

Compatibilidade obrigatoria:

- inventario legado com `channel` continua valido;
- inventario novo com `releaseTrack` e `clientProfile` tambem continua valido;
- se `channel` e `releaseTrack` coexistirem, eles precisam ser coerentes;
- se `profile` e `clientProfile` coexistirem, eles precisam ser coerentes;
- a renderizacao continua produzindo `dhcp-host` e `by-mac/<mac>.ipxe` presos ao contrato atual de `generic.ipxe`, `lab.ipxe` e `rescue.ipxe`.

## Regras operacionais

- Este inventario e lido em runtime a partir de `/etc/ragos-inventory/clients.nix`.
- Ele e validado contra MAC duplicado, hostname duplicado e IP duplicado.
- Inventario vazio falha fechado por padrao, a menos que o runtime do servidor desabilite isso explicitamente para o primeiro boot.
- O `dnsmasq` nao deve ser editado manualmente; as entradas `dhcp-host` sao geradas a partir deste arquivo.
- Rollback do sistema do servidor nao deve ser usado para "reverter" inventario; o inventario tem ciclo de vida proprio neste diretorio.

## Fluxo normal

1. Edite `clients.nix`
2. Aplique o inventario:
   - `sudo ragos-inventory-apply`
3. Se voce tambem alterou o codigo do servidor em `/etc/ragos`, faca:
   - `sudo nixos-rebuild switch --impure --flake /etc/ragos#srv-rag`
4. Confira:
   - `sudo cat /run/ragos-inventory/dnsmasq-hosts.conf`
   - `sudo journalctl -u dnsmasq -b --no-pager | tail -50`
