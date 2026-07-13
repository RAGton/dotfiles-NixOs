# Contrato do plano de instalação do RAGOS

Status: secondary  
Scope: Contrato planejado do plano de instalacao e integracao entre camadas

Este documento define o **contrato formal** entre as camadas do instalador:

```
React UI  →  Rust Backend (Axum)  →  Shell Installer (ragos-install)  →  NixOS Flake
```

Objetivo: garantir que todas as camadas “falem a mesma linguagem” com **validação explícita**, separação de responsabilidades e fluxo auditável.

Arquivos canônicos ligados a este contrato:

- Schema técnico (fonte de verdade): `installer/installer-ui/src/install-plan.schema.json`
- Validação/persistência (backend): `installer/installer-ui/src/main.rs`
- Derivação/normalização (frontend): `installer/installer-ui/src/utils/installPlan.js`
- Executor unattended (shell): `installer/bin/ragos-install`
- Matriz campo a campo validada no repositório: `docs/installer-contract-matrix.md`

---

## Artefatos de runtime

Diretório padrão:

```
/run/ragos-installer/
```

Arquivos criados pelo backend:

| arquivo | função | permissão |
|---|---|---|
| `install-plan.json` | plano declarativo **sem segredos** | `0644` |
| `install-secrets.json` | segredos (senhas) | `0600` |
| `hmac.key` | chave HMAC (integridade do plano) | `0600` |
| `install-plan.sig` | assinatura HMAC-SHA256 do `install-plan.json` | `0600` |
| `runtime.manifest` | checksums SHA256 dos artefatos (anti-corrupção) | `0600` |
| `install.log` | log operacional do executor, com fases e stderr unificado | `0644` |
| `install-state.json` | status do job (`running`, `exit`, `currentPhase`, `lastError`) | `0644` |

O diretório de runtime deve ser `0700`.

---

## Execução canônica (Backend → Shell)

O backend **não implementa lógica destrutiva**. Ele apenas valida e invoca o executor:

```bash
ragos-install unattended \
  --plan /run/ragos-installer/install-plan.json \
  --secrets /run/ragos-installer/install-secrets.json \
  --log /run/ragos-installer/install.log
```

Segurança (gate destrutivo):

- o backend **só** inicia a instalação quando recebe `POST /api/v1/install` com:
  - `{ "confirmWipe": true }`
- o backend só seta `RAGOS_I_UNDERSTAND_THIS_WIPES_DISKS=YES` quando `confirmWipe=true`
- o shell é o **único** responsável por particionamento, montagem, geração do runtime persistente do host e `nixos-install`

Integridade (anti-tampering):

- o backend gera `hmac.key` + `install-plan.sig` no runtime;
- o shell valida a assinatura HMAC-SHA256 antes de consumir o plano;
- se a assinatura falhar, a instalação é abortada.

Anti-corrupção (checksums):

- o backend gera `runtime.manifest` com SHA256 de `install-plan.json`, `install-secrets.json` e `install-plan.sig`;
- o shell valida o manifest antes de iniciar.

---

## Estrutura do `install-plan.json`

O plano é um objeto JSON com **versionamento explícito** e 4 domínios obrigatórios:

```json
{
  "version": 1,
  "disk": { },
  "network": { },
  "locale": { },
  "admin": { }
}
```

### Campo `version`

- `version` é um inteiro.
- No momento, o backend/installer suportam apenas `version = 1`.
- Quando o contrato evoluir de forma incompatível (breaking change), a versão deve ser incrementada e o backend deve rejeitar (ou migrar) versões antigas de forma explícita.

### Domínio `disk`

Campos principais:

- `mode`: `"one"` ou `"two"`
- `profile`: `"single"` ou `"raid"`
- `sysDisk`: caminho do disco que recebe `/` (ou membro de referência do RAID)
- `selectedDisks`: lista explícita dos discos que serão apagados
- `raidLevel`: `"raid0" | "raid1" | "raid5" | "raid10"` (somente quando `profile == "raid"`)
- `luksEnabled`: boolean
- `dataDisk`: disco de dados montado em `/srv/data` (somente no layout split)
- `rootFs`: `"btrfs" | "ext4" | "xfs"`
- `dataFs`: `"btrfs" | "ext4" | "xfs"`

Regras do schema (resumo):

- se `profile != "raid"` e `mode == "one"` então:
  - `selectedDisks` deve ter exatamente 1 disco
  - `dataDisk` não participa do contrato
  - `rootFs` e `dataFs` efetivos ficam em `btrfs`
- se `profile != "raid"` e `mode == "two"` então:
  - o layout é `split`
  - `selectedDisks` deve ter exatamente 2 discos
  - `dataDisk`, `rootFs` e `dataFs` são obrigatórios
- se `profile == "raid"` então:
  - `selectedDisks` é obrigatório e a contagem mínima depende do `raidLevel`
  - `raidLevel` é obrigatório
  - `rootFs` e `dataFs` devem ser `"btrfs"`

Observação operacional:

- o contrato canônico continua compatível com o executor atual (`RAGOS_DISK_MODE`, `RAGOS_SYS_DISK`, `RAGOS_DATA_DISK`, `RAGOS_ROOT_FS`, `RAGOS_DATA_FS`);
- RAID existe como caminho opcional e explícito;
- LVM não faz parte do contrato atual.

### Domínio `network`

Campos principais:

- `hostname`: hostname final
- `interface`: interface LAN/PXE efetiva (`bond0` quando houver agregação)
- `serverIp`: IPv4 do servidor na LAN/PXE
- `prefixLength`: CIDR (ex: `24`)
- `gateway`: IPv4 do gateway na LAN/PXE
- `dns`: lista de IPv4
- `bond`: objeto opcional para agregação LAN em `active-backup`
- `httpPort`: porta HTTP do netboot
- `wan`: objeto persistido no JSON, mas com uplink opcional

#### `network.bond`

Campos:

- `mode`: hoje limitado a `"active-backup"`
- `members`: lista explícita das portas físicas que compõem a LAN agregada

Regras do schema (resumo):

- `bond` é opcional e não substitui `network.interface`; ele complementa a interface lógica efetiva
- quando `bond` existe, `network.interface` passa a representar a interface lógica do bond (ex: `bond0`)
- `members` deve ter pelo menos 2 interfaces distintas
- `network.wan.interface` não pode reutilizar nenhuma interface presente em `bond.members`

#### `network.wan`

Campos:

- `interface`: interface WAN; string vazia significa "sem uplink dedicado"
- `mode`: `"dhcp" | "static" | "pppoe"`
- `address`, `prefixLength`, `gateway`, `dns` (quando `static` e a interface WAN existe)
- `pppoeUser` (quando `pppoe` e a interface WAN existe)

Regras do schema (resumo):

- `wan` continua presente no JSON para manter o contrato estável
- quando `wan.interface == ""`, o servidor opera sem WAN dedicada
- quando `bond` existe, a LAN pode subir em uma interface lógica dedicada enquanto a WAN continua separada
- em `static`: `address`, `prefixLength`, `gateway` e `dns` são obrigatórios e `dns` deve ter `minItems: 1`
- em `pppoe`: `pppoeUser` é obrigatório

### Domínio `locale`

Campos:

- `country`: código ISO-3166-1 alpha-2 (ex: `"BR"`)
- `timezone`: timezone IANA (ex: `"America/Cuiaba"`)
- `locale`: locale do sistema (ex: `"pt_BR.UTF-8"`)
- `keymap`: layout do teclado (ex: `"br-abnt2"`)

Regra operacional:

- `locale.timezone` é a única fonte de verdade persistida para timezone;
- `timeZonePin`, latitude e longitude continuam como metadado de UX do frontend e não entram no contrato persistido;
- o backend rejeita timezone vazio ou fora da lista IANA exposta pelo host (`timedatectl list-timezones`);
- o shell escreve exatamente esse valor no runtime persistente do host como `timeZone = "..."`.

### Domínio `admin`

Campos:

- `user`
- `uid`
- `email`
- `authorizedKeys` (opcional)

Importante:

- **senhas não fazem parte do `install-plan.json`**
- o backend valida política de senha usando `install-secrets.json`

---

## Estrutura do `install-secrets.json`

Arquivo separado para segredos (nunca misturar no plano):

- `adminPassword`
- `adminPasswordConfirm`
- `wanPppoePassword` (opcional; obrigatório quando `network.wan.mode == "pppoe"`)

---

## Exemplo completo

### `install-plan.json`

```json
{
  "version": 1,
  "disk": {
    "mode": "two",
    "profile": "single",
    "selectedDisks": ["/dev/sda", "/dev/sdb"],
    "luksEnabled": true,
    "sysDisk": "/dev/sda",
    "dataDisk": "/dev/sdb",
    "rootFs": "ext4",
    "dataFs": "btrfs"
  },
  "network": {
    "hostname": "srv-rag",
    "interface": "bond0",
    "serverIp": "192.168.100.2",
    "prefixLength": 24,
    "gateway": "192.168.100.1",
    "dns": ["1.1.1.1", "8.8.8.8"],
    "bond": {
      "mode": "active-backup",
      "members": ["enp1s0", "enp3s0"]
    },
    "httpPort": 8080,
    "wan": {
      "interface": "enp2s0",
      "mode": "dhcp"
    }
  },
  "locale": {
    "country": "BR",
    "timezone": "America/Cuiaba",
    "locale": "pt_BR.UTF-8",
    "keymap": "br-abnt2"
  },
  "admin": {
    "user": "rag",
    "uid": 1000,
    "email": "admin@localhost",
    "authorizedKeys": [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... admin@host"
    ]
  }
}
```

### `install-secrets.json`

```json
{
  "adminPassword": "SenhaForte@2026",
  "adminPasswordConfirm": "SenhaForte@2026"
}
```

---

## Evolução do contrato (regras)

0. Mudanças incompatíveis exigem bump de versão:
   - incremente `version` no contrato;
   - ajuste o schema canônico (`const`) e trate migração/compatibilidade no backend e no shell (executor).
1. Atualize o schema canônico em `installer/installer-ui/src/install-plan.schema.json`.
2. Atualize o frontend (derivação/normalização) e o backend (structs + validações) no mesmo ciclo.
3. Atualize o executor shell apenas para **consumir** (nunca para “adivinhar”) novos campos.
4. Mantenha `additionalProperties: false` para evitar payload ambíguo.
5. Segredos sempre em `install-secrets.json` (e/ou arquivos fora da Nix store quando persistidos no sistema instalado).
