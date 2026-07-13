# ragc Channels Explained

Status: canonical
Scope: diferenca entre canal publicado, perfil de build e roteamento por inventario
Last reviewed: 2026-04-09

## Resumo curto

- `canal` e a superficie publica de boot: `generic`, `lab` ou `rescue`
- `perfil` e o target/build do cliente: `desktop-generic`, `desktop-lab`, `hyperv-debug`, `rescue-minimal`
- `releaseTrack` e `clientProfile` existem apenas como aliases compativeis no inventario; eles nao substituem `channel` e `target` no `ragc`
- o inventario decide para qual canal um MAC deve ser roteado
- `ragc switch` publica geracoes e move ponteiros `current-*`; ele nao cadastra clientes
- `release/tag` nao substitui `lab` ou `generic`; promocao oficial vem depois da prova nesses canais

## Canal vs perfil

Canal e perfil se relacionam, mas nao sao a mesma coisa.

| Conceito | Valores atuais | Onde aparece | Papel |
| --- | --- | --- | --- |
| canal | `generic`, `lab`, `rescue` | inventario, `ragc switch --channel`, `generic.ipxe`, `lab.ipxe`, `current-*` | superficie publicada de boot |
| perfil/target | `desktop-generic`, `desktop-lab`, `hyperv-debug`, `rescue-minimal` | `client/profiles/*.nix`, `ragc switch --target` | composicao NixOS que sera buildada |

Mapeamento atual implementado:

- `generic` publica `desktop-generic`
- `lab` publica `desktop-lab`
- `rescue` publica `rescue-minimal`
- `hyperv-debug` tambem publica no canal `lab`, mesmo nao sendo o mesmo perfil de hardware do `desktop-lab`

Em outras palavras: perfil responde "o que eu buildo?"; canal responde "onde essa geracao fica publicada?".

Se a equipe usar a camada nova de semantica do inventario:

- `releaseTrack` continua sendo normalizado para `channel`;
- `clientProfile` continua sendo normalizado para o target/profile atual;
- o `ragc` continua operando em `channel` e `target`, nao nesses aliases.

Detalhes da proposta ficam em [boot-semantics.md](./boot-semantics.md).

## Inventario vs publicacao

Inventario e publicacao tambem sao coisas diferentes.

Inventario:

- mora em `/etc/ragos-inventory/clients.nix`
- declara `mac`, `hostname`, `ip` e, opcionalmente, `channel` e `hardwareClass`
- vira `dhcp-host` do `dnsmasq` e arquivos `by-mac/<mac>.ipxe` quando voce roda `sudo ragos-inventory-apply`

Publicacao:

- parte do checkout local em `~/code/ragos`
- segue para o checkout operacional em `/etc/ragos`
- publica com `sudo ragc switch --channel <generic|lab|rescue>` ou `--target <perfil>`
- move ponteiros em `/srv/data/images` como `current`, `current-generic`, `current-lab`, `previous-*` e atualiza `boot.ipxe`, `generic.ipxe`, `lab.ipxe`, `current.ipxe` e `rescue.ipxe`

Regra pratica:

- mudar inventario nao builda cliente
- publicar cliente nao altera inventario
- o fluxo oficial de promocao e `~/code/ragos` -> `/etc/ragos` -> `lab` -> `generic` -> `release/tag`

## Fluxo MAC -> by-mac -> ipxe -> current-*

O fluxo atual implementado e este:

1. o firmware faz PXE e entra no bootstrap que leva a `boot.ipxe`
2. `boot.ipxe` tenta primeiro `http://<srv-rag>:<porta>/by-mac/${net0/mac}.ipxe`
3. o arquivo `by-mac/<mac>.ipxe` e gerado a partir do inventario e faz chain para `generic.ipxe`, `lab.ipxe` ou `rescue.ipxe`
4. o endpoint de canal resolve a geracao publicada daquele canal
5. o kernel e o initrd saem de `/netboot/current-generic/*`, `/netboot/current-lab/*` ou `/netboot/rescue/*`
6. `current.ipxe` e `/netboot/current/*` continuam como compat global/legada para a geracao ativa mais recente, mas nao substituem o raciocinio por canal

O ponto que mais confunde e o `current` global:

- `current-generic` e o ponteiro estavel do canal `generic`
- `current-lab` e o ponteiro estavel do canal `lab`
- `current` aponta para a ultima geracao nao-rescue promovida globalmente

Por isso, depois de publicar em `lab`, o `current` global pode mudar sem mexer no `current-generic`.

## Exemplo: tc-01 generic / tc-02 lab

Exemplo curto de inventario:

```nix
[
  {
    mac = "52:54:00:64:10:11";
    hostname = "tc-01";
    ip = "192.168.100.110";
    channel = "generic";
    hardwareClass = "physical-generic";
  }
  {
    mac = "52:54:00:64:10:12";
    hostname = "tc-02";
    ip = "192.168.100.111";
    channel = "lab";
    hardwareClass = "physical-lab";
  }
]
```

Resultado operacional esperado:

- `tc-01` gera `/srv/http/by-mac/52:54:00:64:10:11.ipxe` apontando para `/generic.ipxe`
- `tc-01` passa a bootar a geracao em `current-generic`
- `tc-02` gera `/srv/http/by-mac/52:54:00:64:10:12.ipxe` apontando para `/lab.ipxe`
- `tc-02` passa a bootar a geracao em `current-lab`

Se o operador publicar uma nova geracao em `lab`, `tc-02` muda de boot sem obrigar mudanca no inventario. Se o operador mover `tc-02` de `lab` para `generic` no inventario, o cliente passa a chainload `generic.ipxe` mesmo sem rebuild novo.

## Fontes de verdade deste resumo

- `ragc/lib/publish.sh`
- `ragc/lib/boot.sh`
- `ragc/commands/switch.sh`
- `server/network/clients-inventory-lib.nix`
- `server/roles/services.nix`
- `server/network/clients-inventory.README.md`
- `scripts/tests/test-ragc-channels.sh`
- `scripts/tests/test-client-inventory-routing.sh`
