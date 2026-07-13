# Cliente Diskless

Status: canonical
Scope: perfis do cliente diskless, hardware e modelo de publicacao
Last reviewed: 2026-03-27

## Papel

O cliente RAGOS e a imagem NixOS que os endpoints carregam via PXE/iPXE/HTTP.

Direcao oficial:

- cliente diskless real;
- root entregue por `/nix/store` remoto via NFS + overlay tmpfs;
- overlay volatil em RAM;
- persistencia do usuario em `/home` via NFSv4.

Roadmap:

- migrar root do cliente para netboot/SquashFS quando a cadeia estiver completa e validada.

## Estrutura ativa

```text
client/
├── auth/
├── desktop/
├── hardware/
├── modules/
├── profiles/
├── base.nix
├── client.nix
└── default.nix
```

## Perfis

### `desktop-generic`

Perfil principal de producao.

- base comum do cliente;
- baseline fisico em `hardware/physical-generic.nix`;
- desktop principal do endpoint.

### `desktop-lab`

Perfil de laboratorio em hardware fisico.

- mesma base funcional de desktop;
- baseline fisico estreito em `hardware/physical-lab.nix`;
- boot verboso;
- sem Plymouth por contrato enquanto `ragos.profile.bootVerbose = true`;
- agressividade de tuning aceitavel em ambiente de teste.

### `hyperv-debug`

Perfil de laboratorio/CI em Hyper-V.

- mesma base funcional do cliente;
- camada `hardware/hyperv.nix`;
- boot verboso;
- sem Plymouth por contrato enquanto `ragos.profile.bootVerbose = true`;
- diagnostico forte.

### `rescue-minimal`

Perfil de recuperacao.

- sem Plasma;
- sem `pam_mount`;
- SSH habilitado;
- shell em `multi-user.target`;
- ferramentas de rede e NFS;
- sem dependencia do stack completo de desktop.

## Baseline de hardware

### Comum a todos

- firmware redistribuivel;
- microcode Intel/AMD;
- host platform `x86_64-linux`.

### Fisico

- NICs cabeadas comuns para boot;
- suporte grafico basico para Intel/AMD comuns.

### Hyper-V

- modulos `hv_*`;
- dispositivos de laboratorio Hyper-V.

### Fora do baseline universal

- NVIDIA como baseline generico;
- tunings especificos por fabricante;
- modulos adicionados "por garantia".
- parque fisico amplamente heterogeneo tratado como suporte oficial completo.

## Publicacao

O cliente nao e promovido por `nixos-rebuild` no endpoint.

Ele e publicado no servidor com `ragc`.

Fluxo:

[1. `ragc switch --channel <generic|lab|rescue>` (ou `--target <perfil>`) builda o sistema;
2. a geracao e gravada em `/srv/data/images/vYYYYMMDD-HHMMSS`;
3. o bundle de boot HTTP e atualizado;
4. `current`, `previous`, `rescue` e ponteiros por canal (`current-generic`, `current-lab`, `current-rescue`, etc.) ficam coerentes.

Cada geracao persistida contem:

- `bzImage`
- `initrd`
- `.init_path`
- `.kernel_params`
- `manifest.json`
- `.gcroot`

## Arquivos-chave

| Caminho | Funcao |
| --- | --- |
| `client/default.nix` | aponta o cliente padrao para `desktop-generic` |
| `client/base.nix` | base comum do cliente |
| `client/base-diskless.nix` | base do cliente normal com NFS overlay |
| `client/base-rescue.nix` | base minima para recovery |
| `client/modules/boot/` | boot em camadas: initrd, rede, overlay e observabilidade |
| `client/modules/initrd.nix` | wrapper legado para o boot initrd canônico |
| `client/modules/network.nix` | wrapper legado para rede de stage 2 |
| `client/modules/shutdown.nix` | shutdown defensivo para homes NFS |
| `client/profiles/*.nix` | composicao por finalidade |

## Regra operacional

Cliente bom no RAGOS e:

- substituivel;
- previsivel;
- centralizado;
- sem estado local critico.

## Home e setores compartilhados

Contrato atual implementado para sessao de usuario:

1. o usuario autentica;
2. `pam_mount` monta `/home/<usuario>` via NFSv4;
3. so depois o hook de sessao monta os setores compartilhados do usuario;
4. cada setor elegivel aparece em `~/Setores/<grupo>`.

Regras:

- o cliente oficial nao usa `/mnt/groups/...` como contrato principal;
- o diretorio pai visivel para o usuario e `~/Setores`;
- apenas grupos realmente presentes no catalogo do cliente viram mounts de setor;
- `wheel`, `audio`, `video` e grupos locais basicos nao viram mounts de setor.
