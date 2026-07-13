# Processo de Boot

Status: canonical
Scope: fluxo PXE -> iPXE -> HTTP -> netboot -> sessao do cliente
Last reviewed: 2026-04-09

## Estado atual versus direcao oficial

### Direcao oficial

Fluxo oficial implementado neste ciclo:

1. firmware UEFI faz PXE;
2. `dnsmasq` responde DHCP e entrega bootstrap inicial;
3. iPXE sobe e recebe `boot.ipxe` como entrypoint neutro;
4. `boot.ipxe` consulta o inventario por MAC via `by-mac/<mac>.ipxe` e encadeia para `generic.ipxe`, `lab.ipxe` ou `rescue.ipxe`;
5. kernel + initrd sao baixados via HTTP;
6. o root vem de `/nix/store` remoto via NFS;
7. o root descartavel fica em overlay de RAM;
8. `/home` e montado via NFSv4;
9. a sessao do usuario sobe.

Mesmo com a camada nova de semantica no inventario, o fluxo provado hoje
continua sendo esse.

`bootMethod` nao substitui o contrato atual nesta fase:

- `ipxe` continua sendo o baseline real;
- `uefi-http` fica apenas como metadado/control path compativel;
- `uefi-https` continua reservado/futuro sem prova real.

### Roadmap declarado

- migrar para netboot/SquashFS quando o pipeline estiver fechado no codigo e no runbook.

## O que fica no caminho de boot

- PXE para descoberta inicial;
- iPXE para chainload e menu;
- HTTP para entrega de `boot.ipxe`, kernel, initrd e entrypoints;
- geracao publicada com kernel/initrd e root via NFS de `/nix/store`;
- overlay volatil para o root do cliente;
- NFSv4 para `/home`.

## O que nao e destino final

- root stateful por maquina;
- dependencia de disco local funcional;
- persistencia relevante no endpoint;
- declarar SquashFS como se estivesse pronto quando ainda nao esta no contrato implementado.

## Endpoints de boot

| Endpoint | Uso |
| --- | --- |
| `/boot.ipxe` | entrypoint neutro que roteia por MAC antes de cair no menu |
| `/by-mac/<mac>.ipxe` | ponte por inventario para o canal correto |
| `/generic.ipxe` | boot do canal `generic` |
| `/lab.ipxe` | boot do canal `lab` |
| `/current.ipxe` | compat legado para a geracao `current` global |
| `/rescue.ipxe` | boot da geracao `rescue` |
| `/netboot/current-generic/bzImage` | kernel do canal `generic` |
| `/netboot/current-lab/bzImage` | kernel do canal `lab` |
| `/netboot/current/bzImage` | kernel ativo |
| `/netboot/current/initrd` | initrd ativo |
| `/netboot/rescue/bzImage` | kernel do rescue |
| `/netboot/rescue/initrd` | initrd do rescue |

## Validacao rapida

```bash
curl -fsS http://127.0.0.1:8080/boot.ipxe
curl -fsS http://127.0.0.1:8080/by-mac/52:54:00:64:10:11.ipxe
curl -fsS http://127.0.0.1:8080/generic.ipxe
curl -fsS http://127.0.0.1:8080/lab.ipxe
curl -fsS http://127.0.0.1:8080/current.ipxe
curl -fsS http://127.0.0.1:8080/rescue.ipxe
showmount -e 127.0.0.1
ragc doctor
```

## Leitura operacional

O boot do cliente deve ser tratado como cadeia unica:

- rede de descoberta;
- chainload correto;
- artefato HTTP correto;
- geracao publicada integra;
- `/home` remoto acessivel.

Diagnostico bom respeita essa ordem e nao pula etapas.
