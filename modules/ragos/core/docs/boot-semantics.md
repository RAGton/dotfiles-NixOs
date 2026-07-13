# Semantica de Boot e Inventario

Status: proposed
Scope: separacao semantica entre metodo de boot, trilha de release, perfil de cliente e classe de hardware
Last reviewed: 2026-04-09

## Objetivo

Esta nota propoe uma camada de compatibilidade para o inventario do RAGOS sem
trocar o contrato operacional atual de uma vez.

Ela existe para separar quatro eixos que hoje aparecem misturados no uso
cotidiano:

- `bootMethod`
- `releaseTrack`
- `clientProfile`
- `hardwareClass`

## O que continua sendo estado atual

Nada neste documento substitui o contrato canonico atual.

O estado atual implementado e provado hoje continua sendo:

- boot UEFI + PXE + iPXE + HTTP;
- inventario externo em `/etc/ragos-inventory/clients.nix`;
- roteamento por MAC para `generic.ipxe`, `lab.ipxe` ou `rescue.ipxe`;
- publish do cliente via `ragc switch --channel <generic|lab|rescue>`;
- root do cliente por `/nix/store` via NFS + overlay tmpfs;
- `/home` por NFSv4.

## Proposta semantica

### `bootMethod`

Separa o metodo de entrada no fluxo de boot.

Valores iniciais:

- `ipxe`
- `uefi-http`
- `uefi-https`

Regra desta fase:

- default implicito = `ipxe`;
- `ipxe` continua sendo o baseline universal e o unico caminho provado no
  contrato atual;
- `uefi-http` entra apenas como metadado/controle compativel, sem substituir o
  fluxo oficial atual;
- `uefi-https` continua reservado/futuro e nao deve ser tratado como caminho
  entregue sem prova real no codigo, no harness e no runbook.

### `releaseTrack`

Alias semantico compativel de `channel`.

Mapeamento inicial:

- `generic` -> `stable`
- `lab` -> `pilot`
- `rescue` -> `rescue`

### `clientProfile`

Alias semantico compativel do target/profile atual do cliente.

Mapeamento inicial:

- `desktop-generic` -> `workstation`
- `desktop-lab` -> `lab-workstation`
- `rescue-minimal` -> `rescue`
- `hyperv-debug` -> `hyperv-debug`

### `hardwareClass`

Continua sendo um eixo proprio.

Ela nao deve ser absorvida por `clientProfile` nem por `releaseTrack`.

## Regra de compatibilidade

Nesta fase, o inventario deve aceitar:

- formato legado so com `channel` e `hardwareClass`;
- formato novo com `bootMethod`, `releaseTrack`, `clientProfile` e `hardwareClass`;
- formato misto com campos antigos e novos, desde que eles sejam coerentes.

Regras:

- se `channel` e `releaseTrack` coexistirem, eles precisam bater;
- se `profile` e `clientProfile` coexistirem, eles precisam bater;
- combinacoes incoerentes entre canal, profile e hardware precisam falhar de
  forma explicita;
- a renderizacao derivada continua gerando `dhcp-host` e `by-mac/<mac>.ipxe`
  presos ao contrato atual de `generic.ipxe`, `lab.ipxe` e `rescue.ipxe`.

## Nao-objetivos desta fase

- nao trocar o naming do projeto inteiro de uma vez;
- nao remover `channel` ou `profile` do contrato atual;
- nao mover semantica de inventario para dentro do `ragc`;
- nao tratar `uefi-http` ou `uefi-https` como fluxo canonico entregue;
- nao vender SquashFS/netboot como estado atual.

## Estrategia de migracao

### Fase 1 -- compatibilidade

- aceitar o inventario legado e o inventario novo;
- normalizar a semantica nova para o contrato atual;
- validar coerencia e falhar fechado quando houver contradicao.

### Fase 2 -- prova operacional

- manter Day-0 e publish presos ao contrato atual;
- adicionar harness especifico se `uefi-http` deixar de ser apenas metadado;
- nao promover `uefi-https` sem prova real.

### Fase 3 -- eventual promocao

So depois de codigo, testes e runbook fecharem o novo contrato sera seguro
promover essa nomenclatura como superficie canonica.
