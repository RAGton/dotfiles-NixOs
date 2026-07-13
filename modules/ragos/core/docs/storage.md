# Storage

Status: canonical
Scope: layout de storage, imagens publicadas e persistencia
Last reviewed: 2026-03-27

## Objetivo

Separar com clareza:

- o que e codigo;
- o que e runtime do host;
- o que e dado persistente do parque;
- o que e artefato publicado da imagem do cliente.

## Split-storage obrigatorio

### Tier 0 -- sistema do host

Contem:

- NixOS do servidor;
- servicos do host;
- logs e configuracao local.

Esse tier e reinstalavel e nao deve carregar os dados do parque.

### Tier 1 -- dados persistentes

Contem:

- `/srv/data/home`
- `/srv/data/images`
- `/srv/data/snapshots`

Esse tier deve usar BTRFS.

## Subvolumes esperados

- `@ragos_homes`
- `@ragos_images`
- `@ragos_snapshots`

Politica base:

- homes com `compress=zstd:3`;
- imagens com `compress=zstd:15`;
- snapshots e retencao auditaveis.

## Layout operacional

```text
/srv/data/
├── home/         persistencia de usuarios
├── images/       geracoes do cliente publicadas pelo ragc
└── snapshots/    snapshots de GC e de operacao

/srv/http/
├── boot.ipxe
├── generic.ipxe
├── lab.ipxe
├── current.ipxe
├── rescue.ipxe
└── netboot -> /srv/data/images

/srv/tftp/
└── EFI/BOOT/BOOTX64.EFI
```

## Geracoes do cliente

Cada geracao em `/srv/data/images/v*` contem, no minimo:

- `bzImage`
- `initrd`
- `.init_path`
- `.kernel_params`
- `manifest.json`
- `.gcroot`

Ponteiros importantes:

- `current`
- `current-generic`
- `current-lab`
- `current-rescue`
- `previous`
- `previous-generic`
- `previous-lab`
- `previous-rescue`
- `staged`
- `staged-generic`
- `staged-lab`
- `staged-rescue`
- `rescue`

## Politica de GC

- `ragc gc` nao deve remover `current`, `previous`, `staged` ou `rescue`;
- geracoes recentes devem ser preservadas para evitar corrida com publicacao;
- antes de remover algo, o GC deve deixar rastreabilidade em `/srv/data/snapshots`.

## Runtime do host

Nao misture storage do parque com runtime persistente do host.

O runtime do host fica em:

- `/var/lib/ragos/runtime/params.nix`
- `/var/lib/ragos/runtime/hardware-configuration.nix`

Compatibilidade no checkout:

- `server/runtime/params.nix`
- `server/runtime/hardware-configuration.nix`

## Regra operacional

Persistencia do endpoint significa `/home`.

O root do cliente deve ser tratado como imagem publicada e descartavel, nao como area stateful por maquina.
