# Matriz de Contrato do Instalador

Status: secondary  
Scope: Matriz do contrato atual entre UI, backend, shell e modulos NixOS

Esta matriz consolida o contrato real entre as camadas do instalador:

`React UI -> install-plan.json/install-secrets.json -> backend Rust/Axum -> shell ragos-install -> runtime persistente do host -> modulos NixOS`

Ela foi montada a partir dos fontes presentes no repositório, não de relatórios externos.

## Conclusões verificadas

- O backend Rust não injeta variáveis de ambiente campo a campo. Ele persiste `install-plan.json` e `install-secrets.json` e chama `ragos-install unattended --plan ... --secrets ... --log ...`.
- O shell atual já aceita `RAGOS_ADMIN_PASSWORD`, gera o hash localmente com `mkpasswd` e não depende de `RAGOS_ADMIN_HASH`.
- O shell atual já suporta `RAGOS_INSTALL_LOG_FILE`, `RAGOS_REPO_URL` e logs estruturados por fase (`[INPUT]`, `[DISK]`, `[PARTITION]`, `[FS]`, `[MOUNT]`, `[CONFIG]`, `[INSTALL]`, `[VERIFY]`, `[ERROR]`).
- Neste snapshot, `run_nixos_install` não recebe argumentos posicionais. Ela consome variáveis globais preparadas antes por `load_unattended_inputs` e `perform_install`.
- Nem todo estado da UI faz parte do contrato persistido. Alguns campos existem apenas para UX, validação local ou confirmação visual.
- `network.wan` continua presente no JSON, mas `wanInterface = ""` é um estado válido: uplink WAN agora é opcional no backend e no shell unattended.
- `disk.selectedDisks` deixou de ser uma seleção por ordem implícita da UI e passou a representar exatamente os discos que serão apagados pelo executor.

## Fluxo canônico

1. A UI monta o payload via [`installer/installer-ui/src/utils/installPlan.js`](../installer/installer-ui/src/utils/installPlan.js).
2. O backend valida schema e regras em [`installer/installer-ui/src/main.rs`](../installer/installer-ui/src/main.rs).
3. O backend grava os artefatos de runtime e chama [`installer/bin/ragos-install`](../installer/bin/ragos-install).
4. O shell converte JSON em variáveis internas em [`installer/steps/04-storage.sh`](../installer/steps/04-storage.sh).
5. O shell gera o runtime persistente do host via [`installer/lib/params.sh`](../installer/lib/params.sh).
6. O flake importa o runtime em `server/runtime/` e repassa os valores via `specialArgs` em [`flake/lib.nix`](../flake/lib.nix).

## Campos persistidos

| UI wizard | Payload canônico | Backend Rust | Shell | runtime persistente | Consumo NixOS |
| --- | --- | --- | --- | --- | --- |
| `hostName` | `network.hostname` | `InstallPlan.network.hostname` | `HOST_NAME` | `hostName` | `networking.hostName` em [`server/roles/base.nix`](../server/roles/base.nix) |
| `serverIp` | `network.serverIp` | `InstallPlan.network.server_ip` | `SERVER_IP` | `serverIp` | LAN e serviços em [`server/services/networking.nix`](../server/services/networking.nix) e [`server/roles/services.nix`](../server/roles/services.nix) |
| `mgmtNetmask` | `network.prefixLength` | `InstallPlan.network.prefix_length` | `MGMT_PREFIX` | `mgmtPrefixLength` | [`server/services/networking.nix`](../server/services/networking.nix) |
| `mgmtGateway` | `network.gateway` | `InstallPlan.network.gateway` | `MGMT_GATEWAY` | `mgmtGateway` | [`server/services/networking.nix`](../server/services/networking.nix) |
| `mgmtDns` | `network.dns[]` | `InstallPlan.network.dns` | `MGMT_DNS_CSV` | `mgmtDns` | [`server/services/networking.nix`](../server/services/networking.nix) |
| `mgmtInterface` | `network.interface` | `InstallPlan.network.interface` | `MGMT_IFACE` | `mgmtInterface` | [`server/services/networking.nix`](../server/services/networking.nix) e [`server/roles/base.nix`](../server/roles/base.nix) |
| `mgmtBondEnabled` + `mgmtBondMembers` | `network.bond` | `InstallPlan.network.bond` | `MGMT_BOND_MODE` + `MGMT_BOND_MEMBERS_CSV` | `mgmtBondMode` + `mgmtBondMembers` | cria o bond LAN lógico e escraviza portas em [`server/services/networking.nix`](../server/services/networking.nix) |
| `httpPort` | `network.httpPort` | `InstallPlan.network.http_port` | `HTTP_PORT` | `httpPort` | [`server/roles/services.nix`](../server/roles/services.nix) e [`server/roles/base.nix`](../server/roles/base.nix) |
| `wanInterface` | `network.wan.interface` | `InstallPlan.network.wan.interface` | `WAN_IFACE` | `wanInterface` | opcional; vazio significa "sem uplink dedicado" em [`server/services/networking.nix`](../server/services/networking.nix) |
| `wanMode` | `network.wan.mode` | `InstallPlan.network.wan.mode` | `WAN_MODE` | `wanMode` | [`server/services/networking.nix`](../server/services/networking.nix) |
| `wanAddress` | `network.wan.address` | `InstallPlan.network.wan.address` | `WAN_ADDRESS` | `wanAddress` | [`server/services/networking.nix`](../server/services/networking.nix) |
| `wanNetmask` | `network.wan.prefixLength` | `InstallPlan.network.wan.prefix_length` | `WAN_PREFIX` | `wanPrefixLength` | [`server/services/networking.nix`](../server/services/networking.nix) |
| `wanGateway` | `network.wan.gateway` | `InstallPlan.network.wan.gateway` | `WAN_GATEWAY` | `wanGateway` | [`server/services/networking.nix`](../server/services/networking.nix) |
| `wanDns` | `network.wan.dns[]` | `InstallPlan.network.wan.dns` | `WAN_DNS_CSV` | `wanDns` | [`server/services/networking.nix`](../server/services/networking.nix) |
| `pppoeUser` | `network.wan.pppoeUser` | `InstallPlan.network.wan.pppoe_user` | `PPPOE_USER` | `wanPppoeUser` | [`server/services/networking.nix`](../server/services/networking.nix) |
| `country` | `locale.country` | `InstallPlan.locale.country` | sem equivalente | não persiste em `params.nix` | sem consumo Nix atual |
| `timeZone` | `locale.timezone` | `InstallPlan.locale.timezone` | `TIME_ZONE` | `timeZone` | [`server/roles/base.nix`](../server/roles/base.nix); backend valida contra `timedatectl list-timezones` |
| `locale` | `locale.locale` | `InstallPlan.locale.locale` | `LOCALE` | `locale` | [`server/roles/base.nix`](../server/roles/base.nix) |
| `keyMap` | `locale.keymap` | `InstallPlan.locale.keymap` | `KEY_MAP` | `keyMap` | [`server/roles/base.nix`](../server/roles/base.nix) |
| `adminUser` | `admin.user` | `InstallPlan.admin.user` | `ADMIN_USER` | `adminUser` | [`server/roles/base.nix`](../server/roles/base.nix) |
| `adminUid` | `admin.uid` | `InstallPlan.admin.uid` | `ADMIN_UID` | `adminUid` | [`server/roles/base.nix`](../server/roles/base.nix) |
| `adminEmail` | `admin.email` | `InstallPlan.admin.email` | `ADMIN_EMAIL` | `adminEmail` | hoje não há consumo operacional direto confirmado |
| `adminAuthorizedKeys` | `admin.authorizedKeys[]` | `InstallPlan.admin.authorized_keys` | `ADMIN_AUTHORIZED_KEYS` | `adminAuthorizedKeys` | [`server/roles/base.nix`](../server/roles/base.nix) |
| `diskMode` | `disk.mode` | `InstallPlan.disk.mode` | `DISK_MODE` | diferencia `single` (`one`) de `split` (`two`) quando `profile == single` | sem leitura direta posterior; o efeito principal ocorre no shell |
| `diskProfile` | `disk.profile` | `InstallPlan.disk.profile` | `DISK_PROFILE` | define `single` vs `raid` e controla `rootRaid` | [`server/services/boot.nix`](../server/services/boot.nix) para `rootRaid` |
| `selectedDisks` | `disk.selectedDisks[]` | `InstallPlan.disk.selected_disks` | `SELECTED_DISKS_CSV` | não persiste diretamente | lista explícita dos discos apagados: 1 no single, 2 no split, N membros no RAID |
| `raidLevel` | `disk.raidLevel` | `InstallPlan.disk.raid_level` | `RAID_LEVEL` | não persiste diretamente | usado só no shell para criar RAID |
| `luksEnabled` | `disk.luksEnabled` | `InstallPlan.disk.luks_enabled` | `LUKS_ENABLED` | não persiste diretamente | usado só no shell durante particionamento |
| `sysDisk` | `disk.sysDisk` | `InstallPlan.disk.sys_disk` | `SYS_DISK` | não persiste diretamente | usado só no shell durante particionamento |
| `dataDisk` | `disk.dataDisk` | `InstallPlan.disk.data_disk` | `DATA_DISK` | somente no layout `split`; indireto: `INSTALL_DATA_DEVICE` -> `dataDisk` | [`server/services/storage.nix`](../server/services/storage.nix) |
| `rootFs` | `disk.rootFs` | `InstallPlan.disk.root_fs` | `ROOT_FS` | não persiste diretamente | usado só no shell durante formatação do root |
| `dataFs` | `disk.dataFs` | `InstallPlan.disk.data_fs` | `DATA_FS` | `dataFsType` | [`server/services/storage.nix`](../server/services/storage.nix) |

## Segredos

| UI wizard | `install-secrets.json` | Backend Rust | Shell | Destino final |
| --- | --- | --- | --- | --- |
| `adminPassword` | `adminPassword` | `InstallSecrets.admin_password` | `ADMIN_PASSWORD` | hash SHA-512 gerado pelo shell e escrito como `adminHashedPassword` em `params.nix` |
| `adminPasswordConfirm` | `adminPasswordConfirm` | `InstallSecrets.admin_password_confirm` | validado no backend, não persiste em `params.nix` | sem consumo posterior |
| `pppoePassword` | `wanPppoePassword` | `InstallSecrets.wan_pppoe_password` | `PPPOE_PASSWORD` | persistido fora da Nix store em `/mnt/etc/ragos/wan-pppoe.env` |

## Estado de UI que não faz parte do contrato persistido

Os campos abaixo existem hoje na UI, mas não entram no `install-plan.json` nem em `params.nix`:

- `eulaAccepted`
- `timeZonePin`
- `timeZoneLatitude`
- `timeZoneLongitude`
- `timeZoneCountryCode`
- `netIfacesCount`
- `wanIdentified`
- `lanIdentified`
- `storageProfile`
- `destructiveConfirmed`

Esses campos hoje servem para UX, validação local, visualização ou confirmação operacional. Se algum deles precisar afetar o sistema instalado, o contrato terá de ser expandido formalmente no schema, no backend, no shell e em `params.nix`.

## Telemetria operacional da instalação

O backend agora deriva estado operacional a partir de `install.log` e expõe em `GET /api/v1/status`:

- `currentPhase`: última fase válida observada no log
- `lastError`: última linha de erro concreta
- `lastLogLine`: última linha útil recebida

Isso não substitui o log bruto, mas evita falso positivo de UX quando a falha real ocorreu em particionamento, formatação, mount ou `nixos-install`.
