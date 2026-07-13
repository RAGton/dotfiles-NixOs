# Plano de Refatoração Arquitetural do RAGOS

Status: archived  
Scope: Plano historico de refatoracao arquitetural

## Objetivo

Transformar o RAGOS em uma plataforma diskless NixOS com arquitetura de produto, operação previsível e fronteiras de responsabilidade explícitas.

Princípios de refatoração:

- estabilidade antes de novidade;
- estado operacional separado de código-fonte;
- módulos pequenos e auditáveis;
- fluxo de boot documentado ponta a ponta;
- CLI e instalador como interfaces oficiais de operação.

## Status da migração

### ✅ Fase 0 — Congelamento Arquitetural (CONCLUÍDA)
Objetivo: Eliminar ambiguidades internas, consolidar árvores oficiais e formalizar responsabilidades.

- **Árvores Oficiais**: `server/`, `client/`, `installer/`, `ragc/`, `flake/` e `docs/` consolidadas como canônicas.
- **Remoção de Legado**: Árvores `SRV-RAGOS/` e `ragos/` marcadas como obsoletas e removidas do fluxo operacional.
- **Orquestração**: `flake.nix` estabilizado como orquestrador puro, delegando lógica auxiliar para `flake/`.
- **Responsabilidades Formalizadas**: Papéis de `dnsmasq`, `nginx`, `NFS`, `initrd` e `ragc` explicitados em toda a documentação.
- **Storage Operacional**: Clarificação das camadas de distribuição (`/srv/http`) vs. armazenamento imutável (`/srv/data/images`).
- **Alinhamento Documental**: README, Runbook e Docs alinhados com o fluxo real de publicação e operação.

---

## Diagnóstico do estado atual

Pontos positivos já existentes:

- parâmetros centrais e validações em [flake.nix](../flake.nix);
- separação inicial entre servidor, cliente e instalador;
- cliente diskless com overlay de `/nix/store` em [client/modules/diskless-core.nix](../client/modules/diskless-core.nix);
- publicação versionada via [ragc/default.nix](../ragc/default.nix);
- layout BTRFS operacional em [server/modules/storage.nix](../server/modules/storage.nix);
- observabilidade inicial em [server/modules/monitoring.nix](../server/modules/monitoring.nix).

Principais dívidas arquiteturais:

- `flake.nix` concentra demais: parâmetros, validações, packages e sistemas;
- coexistem diretórios com semântica histórica (`ragos/`, `installer/`) sem fronteira clara de domínio;
- o instalador shell ainda é monolítico;
- o backend do instalador tem escopo grande demais para um único binário/arquivo;
- responsabilidades de boot, storage e publicação ainda estão corretas, mas espalhadas;
- a CLI `ragc` já opera bem, porém ainda mistura build, publicação, rollback e diagnóstico em um único script.

---

## Arquitetura-alvo do repositório

Estrutura proposta:

```text
.
├── flake.nix
├── flake/
│   ├── params.nix
│   ├── validations.nix
│   ├── lib.nix
│   ├── server.nix
│   ├── client.nix
│   ├── installer.nix
│   └── packages.nix
├── core/
│   ├── lib/
│   │   ├── network.nix
│   │   ├── storage.nix
│   │   ├── validation.nix
│   │   └── naming.nix
│   └── profiles/
│       ├── diskless.nix
│       ├── netboot.nix
│       └── observability.nix
├── server/
│   ├── default.nix
│   ├── hardware/
│   ├── modules/
│   │   ├── base.nix
│   │   ├── network/
│   │   │   ├── default.nix
│   │   │   ├── dnsmasq.nix
│   │   │   ├── nginx.nix
│   │   │   ├── firewall.nix
│   │   │   └── nfs.nix
│   │   ├── storage/
│   │   │   ├── default.nix
│   │   │   ├── btrfs-layout.nix
│   │   │   ├── snapshots.nix
│   │   │   └── exports.nix
│   │   ├── security/
│   │   │   ├── ssh.nix
│   │   │   ├── mac-allowlist.nix
│   │   │   └── hardening.nix
│   │   └── observability/
│   │       ├── prometheus.nix
│   │       ├── grafana.nix
│   │       └── exporters.nix
│   └── profiles/
│       ├── lab.nix
│       └── production.nix
├── client/
│   ├── default.nix
│   ├── hardware/
│   ├── modules/
│   │   ├── base.nix
│   │   ├── boot/
│   │   │   ├── default.nix
│   │   │   ├── initrd.nix
│   │   │   ├── network.nix
│   │   │   └── filesystem-overlay.nix
│   │   ├── desktop/
│   │   │   ├── plasma6.nix
│   │   │   └── applications.nix
│   │   ├── locale.nix
│   │   ├── users.nix
│   │   └── performance.nix
│   └── profiles/
│       ├── plasma-lab.nix
│       └── minimal.nix
├── installer/
│   ├── default.nix
│   ├── iso.nix
│   ├── params.nix
│   ├── bin/
│   │   └── ragos-install
│   ├── lib/
│   │   ├── common.sh
│   │   ├── disk.sh
│   │   ├── filesystem.sh
│   │   ├── network.sh
│   │   ├── nixos.sh
│   │   ├── params.sh
│   │   ├── security.sh
│   │   └── ui.sh
│   ├── steps/
│   │   ├── 01-welcome.sh
│   │   ├── 02-localization.sh
│   │   ├── 03-network.sh
│   │   ├── 04-storage.sh
│   │   ├── 05-users.sh
│   │   ├── 06-summary.sh
│   │   └── 07-install.sh
│   └── installer-ui/
│       ├── backend/
│       ├── frontend/
│       └── shared/
├── ragc/
│   ├── default.nix
│   ├── lib/
│   │   ├── build.sh
│   │   ├── publish.sh
│   │   ├── rollback.sh
│   │   ├── doctor.sh
│   │   ├── gc.sh
│   │   └── common.sh
│   └── commands/
│       ├── switch.sh
│       ├── rollback.sh
│       ├── list.sh
│       ├── status.sh
│       ├── gc.sh
│       └── doctor.sh
├── scripts/
│   ├── dev/
│   ├── test/
│   └── migration/
└── docs/
    ├── architecture.md
    ├── boot-process.md
    ├── network.md
    ├── storage.md
    ├── client.md
    ├── server.md
    ├── runbook.md
    ├── troubleshooting.md
    ├── roadmap.md
    └── refactor-plan.md
```

Decisão principal: substituir organização por origem histórica por organização por domínio operacional.

---

## Mapa de migração do estado atual

| Atual | Alvo | Motivo |
| --- | --- | --- |
| `SRV-RAGOS/` | `server/` | nomenclatura uniforme por domínio |
| `ragos/client/` | `client/` | remoção de profundidade desnecessária |
| `ragos/client/ragc.nix` | `ragc/default.nix` | CLI tratada como produto próprio |
| `ragos/pxe/` | `server/pxe/` | assets de boot promovidos à árvore canônica do servidor |
| `installer/ragos-install.sh` | `installer/bin/ragos-install` + `installer/lib/` + `installer/steps/` | instalador modular |
| `installer/installer-ui/src/main.rs` | `installer/installer-ui/backend/` | backend modular e testável |

---

## Refatoração do flake

### Problema atual

O arquivo [flake.nix](../flake.nix) já está funcional e possui validações úteis, mas concentra responsabilidades demais:

- leitura de parâmetros;
- validação;
- composição de packages;
- composição de sistemas NixOS;
- devShell.

### Arquitetura alvo do flake

```text
flake.nix
└── flake/
    ├── params.nix
    ├── validations.nix
    ├── lib.nix
    ├── server.nix
    ├── client.nix
    ├── installer.nix
    └── packages.nix
```

### Regras

1. `flake.nix` deve apenas orquestrar.
2. O runtime persistente do host em `/var/lib/ragos/runtime` é a fonte de parâmetros consumida pelo flake no sistema instalado; o instalador apenas gera e persiste esses arquivos no alvo.
3. `flake/validations.nix` deve centralizar todas as pré-condições.
4. `flake/lib.nix` deve expor helpers compartilhados, como subnet derivada, URLs de netboot, nomes de host e paths padrão.
5. `flake/server.nix`, `flake/client.nix` e `flake/installer.nix` devem devolver `nixosSystem` prontos.
6. `flake/packages.nix` deve publicar `ragc`, ferramentas auxiliares e possíveis utilitários de debug.

### Exemplo de output alvo

```nix
{
  outputs = inputs:
    let
      runtime = import ./server/runtime;
      ragosParams = runtime.params;
      check = import ./flake/validations.nix ragosParams;
      flakeLib = import ./flake/lib.nix { inherit ragosParams check; };
      specialArgs = flakeLib.mkSpecialArgs;
    in {
      inherit ragosParams;
      nixosConfigurations = {
        srv-rag = import ./flake/server.nix { inherit inputs specialArgs; };
        ragos-client = import ./flake/client.nix { inherit inputs specialArgs; };
        ragos-installer-iso = import ./flake/installer.nix { inherit inputs specialArgs; };
      };
    };
}
```

### Validações recomendadas

Adicionar validações semânticas, não só sintáticas:

- `serverIp` deve pertencer à sub-rede de gestão;
- `mgmtGateway` não pode ser igual a `serverIp`;
- `httpPort` não pode conflitar com portas reservadas pelo stack local;
- `dataDisk` não pode coincidir com o disco de sistema em modo `two`;
- `adminUid` deve estar em faixa segura e previsível;
- `mgmtDns` deve ser lista de IPs válidos, não string tardia.

### Benefício

Menor acoplamento, `nix flake show` mais legível, validação previsível e preparo natural para `flake-parts` no futuro sem introduzir complexidade agora.

---

## Refatoração do instalador

### Diagnóstico

[installer/bin/ragos-install](../installer/bin/ragos-install) já é auditável e funcional, mas sua escala atual dificulta:

- testes por responsabilidade;
- reuso entre TTY e UI web/local;
- adição de novos passos;
- rastreabilidade do pipeline.

### Arquitetura alvo

```text
installer/
├── bin/
│   └── ragos-install
├── lib/
│   ├── common.sh
│   ├── disk.sh
│   ├── filesystem.sh
│   ├── network.sh
│   ├── nixos.sh
│   ├── params.sh
│   ├── security.sh
│   └── ui.sh
└── steps/
    ├── 01-welcome.sh
    ├── 02-localization.sh
    ├── 03-network.sh
    ├── 04-storage.sh
    ├── 05-users.sh
    ├── 06-summary.sh
    └── 07-install.sh
```

### Responsabilidade por biblioteca

| Arquivo | Responsabilidade |
| --- | --- |
| `common.sh` | logging, `die`, checagem de dependências, traps, utilidades |
| `disk.sh` | descoberta de discos, wipe, GPT, RAID futuro |
| `filesystem.sh` | mkfs, subvolumes BTRFS, mounts em `/mnt` |
| `network.sh` | validação de IP, máscara, gateway, DNS, prefixo |
| `nixos.sh` | clone/cópia do repo, escrita de params, `nixos-install` |
| `params.sh` | serialização segura para `/var/lib/ragos/runtime/params.nix` |
| `security.sh` | hash de senha, confirmação destrutiva, hardening do processo |
| `ui.sh` | abstração única para `whiptail`, `dialog` e modo plain |

### Pipeline alvo

1. `01-welcome.sh`: EULA, risco destrutivo, checagem do ambiente.
2. `02-localization.sh`: locale, keymap, timezone.
3. `03-network.sh`: gestão, LAN/PXE, WAN futura, validação de topologia.
4. `04-storage.sh`: perfil de disco, BTRFS, subvolumes, validação de risco.
5. `05-users.sh`: admin, senha, chaves SSH.
6. `06-summary.sh`: diff do plano final, checksum do plano, confirmação.
7. `07-install.sh`: particiona, monta, escreve `params.nix`, executa `nixos-install`, pós-validação.

### UI do instalador

Separar o backend Rust atual de [installer/installer-ui/src/main.rs](../installer/installer-ui/src/main.rs) em módulos:

```text
installer-ui/backend/src/
├── main.rs
├── app_state.rs
├── api/
│   ├── disks.rs
│   ├── network.rs
│   ├── plan.rs
│   ├── install.rs
│   └── timezones.rs
├── domain/
│   ├── plan.rs
│   ├── validation.rs
│   └── install_state.rs
├── services/
│   ├── command_runner.rs
│   ├── plan_store.rs
│   └── installer_runner.rs
└── util/
    ├── net.rs
    ├── geo.rs
    └── fs.rs
```

### Regra de produto

A UI não deve “instalar por conta própria”. Ela deve apenas montar e validar um plano. O executor oficial continua sendo o instalador shell modular, porque ele é mais auditável e mais fácil de depurar em ambiente de recuperação.

---

## Pipeline de boot explícito

### Fluxo alvo

```text
UEFI
→ PXE DHCP
→ BOOTX64.EFI
→ iPXE
→ boot.ipxe
→ kernel + initrd
→ initrd monta NFS ro
→ overlay /nix/store
→ switch_root
→ systemd
→ /home via NFS
→ login
```

### Responsabilidade formal por componente

| Componente | Responsabilidade única |
| --- | --- |
| `dnsmasq` | DHCP, TFTP e entrega do chainload inicial |
| `iPXE` | seleção de entrypoint HTTP e menu de boot |
| `nginx` | servir `boot.ipxe`, `kernel`, `initrd`, perfis de boot e artefatos estáticos |
| `NFS` | exportar `/nix/store` em ro e `/home` em rw |
| `initrd` | rede mínima, mount NFS, overlay, handoff para `systemd` |
| `ragc` | build, versionamento, publicação e rollback das imagens bootáveis |

### Melhorias recomendadas

1. Introduzir diretório lógico único de publicação:

   ```text
   /srv/http/
   ├── boot/
   │   ├── current.ipxe
   │   ├── rescue.ipxe
   │   └── menu.ipxe
   └── netboot/
      ├── current -> /srv/data/images/current
      └── generations/
   ```

2. Adicionar entrypoint de recuperação:
   - `rescue.ipxe` com boot de imagem mínima de diagnóstico;
   - útil para troubleshooting de NFS, overlay e GPU.

3. Versionar manifesto de cada geração:

    ```json
    {
       "generation": "v20260306-120000",
       "kernel": "bzImage",
       "initrd": "initrd",
       "system": "/nix/store/...-nixos-system-ragos-client",
       "createdAt": "2026-03-06T12:00:00Z",
       "flakeRevision": "<git-rev>"
    }
    ```

4. Tornar o `boot.ipxe` gerado um dispatcher estável que aponta para `current.ipxe`.

5. Documentar claramente dependências entre serviços:
   - `dnsmasq` depende de TFTP pronto;
   - `nginx` depende de `/srv/http` pronto;
   - `NFS` depende de `/srv/data/home` montado;
   - publicação via `ragc` depende de `nginx` enxergar `/srv/http/netboot`.

---

## Arquitetura de storage

### Layout alvo obrigatório

```text
/srv
├── tftp
├── http
└── data
    ├── home
    ├── images
    └── snapshots
```

### Subvolumes BTRFS

```text
@root
@nix
@srv
@ragos_homes
@ragos_images
@ragos_snapshots
```

### Ajustes arquiteturais

1. Tornar BTRFS o perfil oficial de produção.
2. Tratar `ext4` e `xfs` apenas como perfis de compatibilidade de instalação, não como caminho principal.
3. Formalizar política de snapshot:
   - `hourly` para metadados críticos opcionais;
   - `daily` para homes;
   - retenção configurável via parâmetros.
4. Criar política de promoção de geração:
   - imagem publicada só vira `current` após validação de integridade;
   - checksum de `kernel` e `initrd`.
5. Introduzir manifests e lockfiles por geração em `/srv/data/images/<geração>/`.

### Direção operacional

- `/srv/data/home`: persistência do usuário;
- `/srv/data/images`: artefatos imutáveis de boot publicados pelo `ragc`;
- `/srv/data/snapshots`: retenção e recuperação;
- `/srv/http`: camada de distribuição, não de armazenamento definitivo.

---

## Cliente diskless

### Modelo alvo

```text
tmpfs /
NFS /nix/.ro-store
tmpfs /nix/.rw-store
overlay /nix/store
NFS /home
```

### Regras de robustez

1. Todo estado persistente deve sair do cliente.
2. `/var` deve ser explicitamente classificado:
   - volátil por padrão;
   - persistente apenas se futuramente houver necessidade declarada.
3. `systemd` deve ter ordem explícita para mounts e overlay.
4. O cliente deve bootar mesmo quando a GUI falhar, preservando acesso TTY/SSH de recuperação.
5. Separar módulo `boot` do módulo `desktop`, para existir perfil `minimal` de diagnóstico.

### Melhorias técnicas

- criar `client/profiles/minimal.nix` para boot de manutenção;
- adicionar testes com QEMU para validar:
  - DHCP ok;
  - download de `boot.ipxe`;
  - mount de `/nix/.ro-store`;
  - mount de `/home`;
  - chegada ao `multi-user.target`;
- endurecer timeout e retry de NFS no initrd;
- adicionar telemetria local mínima de boot via `journalctl -b` e marcadores de estágio;
- separar `filesystem-diskless.nix`, `initrd.nix` e `network.nix` sob `client/modules/boot/`.

### Perfil de produto

- `plasma-lab`: desktop completo para laboratório e salas de aula;
- `minimal`: diagnóstico, manutenção e recuperação;
- `kiosk` futuro: uso institucional restrito.

---

## Refatoração da CLI `ragc`

### Diagnóstico da CLI

A base pública em [ragc/default.nix](../ragc/default.nix) já cobre o ciclo principal. A compatibilidade legada via `ragos/client/ragc.nix` foi removida após a migração, mas a CLI ainda precisa de fronteiras internas mais claras.

### Estrutura alvo

```text
ragc/
├── default.nix
├── lib/
│   ├── common.sh
│   ├── build.sh
│   ├── publish.sh
│   ├── rollback.sh
│   ├── inspect.sh
│   ├── doctor.sh
│   └── gc.sh
└── commands/
    ├── switch.sh
    ├── rollback.sh
    ├── list.sh
    ├── status.sh
    ├── gc.sh
    └── doctor.sh
```

### Semântica alvo dos comandos

| Comando | Função |
| --- | --- |
| `ragc switch` | builda, valida, publica e promove geração |
| `ragc rollback [geração]` | alterna geração ativa e regenera dispatcher de boot |
| `ragc list` | lista gerações, tamanhos, hash, revisão e estado |
| `ragc status` | mostra geração ativa, serviços, exports e URLs |
| `ragc gc` | aplica política de retenção |
| `ragc doctor` | valida DNS/DHCP/HTTP/NFS/paths/links/permissions |

### Melhorias críticas

1. `switch` em duas fases:
   - `build + stage`;
   - `promote` apenas se todos os artefatos existirem.
2. `doctor` com checks estruturados:
   - `dnsmasq` ativo;
   - `nginx` ativo;
   - NFS exportando corretamente;
   - `BOOTX64.EFI` presente;
   - `boot.ipxe` legível;
   - geração atual íntegra.
3. `status` deve exibir também:
   - porta HTTP;
   - geração ativa;
   - hash de manifesto;
   - ocupação de `/srv/data`.
4. log em arquivo opcional:
   - `/var/log/ragc.log`.

---

## Segurança

### Controles mínimos obrigatórios

1. MAC allowlist no `dnsmasq`.
2. Firewall com `default deny` e portas mínimas.
3. Validação de topologia de rede no instalador.
4. SSH somente com política definida por perfil.
5. NFS com export mínimo e sub-rede derivada de parâmetros válidos.
6. validação cruzada de discos para evitar destruição indevida.

### Próximos controles

- perfis `lab` e `production` com políticas diferentes;
- rotação de chaves SSH administrativas;
- assinatura opcional de manifests de boot;
- auditoria de alterações em `/var/lib/ragos/runtime/params.nix`.

---

## Observabilidade e operação

### O que já existe

Base inicial em [server/modules/monitoring.nix](../server/modules/monitoring.nix).

### Evolução recomendada

Separar observabilidade por camadas:

```text
server/modules/observability/
├── prometheus.nix
├── grafana.nix
├── exporters.nix
└── alerts.nix
```

### Métricas mínimas de produto

- clientes ativos por janela;
- latência NFS;
- tempo de boot por geração;
- taxa de falha em PXE/iPXE;
- ocupação de `/srv/data/home` e `/srv/data/images`;
- gerações publicadas e ativa;
- integridade de symlinks `current`.

### Operação

Adicionar ao runbook:

- rollback operacional em 1 comando;
- promoção de nova imagem;
- restauração de home por snapshot;
- validação do boot após atualização;
- recuperação de serviço `dnsmasq`, `nginx` e `nfs-server`.

---

## Sequência recomendada de implementação

### Fase 1 — reorganização semântica

- criar nova árvore `server/`, `client/`, `ragc/`, `flake/`;
- manter compatibilidade com paths antigos por wrappers temporários;
- migrar documentação para nova nomenclatura.

### Fase 2 — flake modular

- extrair `params`, `validations`, `packages`, `server`, `client`, `installer`;
- manter outputs com os mesmos nomes públicos.

### Fase 3 — instalador modular

- quebrar shell monolítico em libs + steps;
- fazer backend Rust invocar apenas `installer/bin/ragos-install` com plano serializado.

### Fase 4 — `ragc` modular

- extrair comandos e biblioteca interna;
- adicionar manifesto por geração;
- melhorar `doctor` e `status`.

### Fase 5 — testes e hardening

- testes QEMU de boot;
- validações mais fortes de rede/disco;
- allowlist de MAC;
- perfil minimal de recuperação.

---

## Roadmap técnico ampliado

### Próximos marcos

1. HTTPBoot nativo UEFI para hardware compatível.
2. dashboard web de administração.
3. suporte a cluster de servidores RAGOS com roles explícitos.
4. cache Nix local para acelerar rebuilds.
5. build farm para geração rápida de imagens.
6. imagens de recuperação e manutenção.
7. inventário de clientes por MAC, hostname, última geração e último boot.

### Direção estratégica

O RAGOS deve evoluir para três planos de produto:

- **Lab Edition**: implantação simples para ambientes educacionais;
- **Enterprise On-Prem**: auditoria, observabilidade e política de acesso;
- **Scale Edition**: múltiplos servidores, cache Nix e build farm.

---

## Conclusão

A refatoração recomendada não muda o coração do RAGOS. Ela preserva:

- boot PXE/iPXE;
- servidor on-premises;
- NixOS declarativo;
- cliente diskless;
- persistência centralizada.

O que muda é a forma de organizar e operar o sistema:

- domínios explícitos;
- flake pequeno e orquestrador;
- instalador modular;
- `ragc` tratado como produto operacional;
- boot pipeline formalizado;
- storage e observabilidade com política clara.

Resultado esperado: uma plataforma diskless profissional, auditável e reproduzível, pronta para laboratórios, estações remotas e ambientes institucionais.
