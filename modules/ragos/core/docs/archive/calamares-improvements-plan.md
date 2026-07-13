# Plano de Evolução do Instalador RAGOS inspirado no Calamares

Status: archived  
Scope: Plano historico de evolucao do instalador

Este documento consolida a análise arquitetural do Calamares e traduz os aprendizados para uma evolução prática do instalador do RAGOS.

O objetivo não é copiar o Calamares literalmente, mas absorver seus pontos fortes sem perder as características já valiosas do RAGOS:

- UI web moderna;
- backend Rust simples e auditável;
- executor shell explícito;
- modo kiosk na ISO;
- integração direta com o projeto NixOS do repositório.

---

## Resumo executivo

O Calamares se destaca por quatro fundamentos:

1. fluxo declarativo;
2. separação forte entre telas e execução;
3. estado compartilhado central e consistente;
4. fila de jobs com progresso real.

No RAGOS, esses conceitos devem ser traduzidos para a stack atual com a seguinte prioridade:

1. criar um contrato formal único de instalação;
2. separar `uiState` de `installPlan`;
3. tornar o fluxo do wizard declarativo;
4. quebrar a execução em estágios nomeados e ponderados;
5. adicionar pré-flight técnico obrigatório;
6. suportar presets e perfis bloqueáveis.

---

## Diagnóstico do estado atual do RAGOS

Hoje o instalador já possui ganhos importantes:

- wizard React funcional;
- backend Rust com validações centrais em [installer/installer-ui/src/main.rs](../installer/installer-ui/src/main.rs);
- APIs locais para discos, rede, timezone, locales e execução;
- executor shell auditável em `installer/bin/ragos-install`;
- ISO kiosk endurecida em [installer/iso.nix](../installer/iso.nix).

Mas ainda existem limitações arquiteturais:

- o estado de UI e o plano instalável convivem no mesmo objeto `wizard`;
- parte dos campos existe apenas para experiência visual e checklist;
- o fluxo de etapas está codificado em [installer/installer-ui/src/App.jsx](../installer/installer-ui/src/App.jsx);
- o backend valida `PlanRequest`, mas ainda não há schema formal compartilhado entre frontend, backend e testes;
- a execução ainda é percebida como uma esteira única, e não como estágios semânticos.

---

## Princípios arquiteturais extraídos do Calamares

### 1. Sequência declarativa

Inspirado em [calamares/settings.conf](../calamares/settings.conf), o fluxo do instalador deve ser descrito em um arquivo de configuração, e não apenas em código.

### 2. Estado compartilhado com contrato único

Inspirado em [calamares/src/libcalamares/GlobalStorage.h](../calamares/src/libcalamares/GlobalStorage.h), o RAGOS deve ter um contrato claro para o que é persistido como intenção de instalação.

### 3. Execução em fila de jobs

Inspirado em [calamares/src/libcalamares/JobQueue.h](../calamares/src/libcalamares/JobQueue.h) e [calamares/src/libcalamaresui/viewpages/ExecutionViewStep.cpp](../calamares/src/libcalamaresui/viewpages/ExecutionViewStep.cpp), o processo de instalação deve ser representado por etapas explícitas.

### 4. Configuração externa e branding

Inspirado em [calamares/src/branding/default/branding.desc](../calamares/src/branding/default/branding.desc), o comportamento visual e parte da experiência do instalador devem sair do código quando possível.

### 5. Configuração modular validada

Inspirado nos módulos `.conf` e `.schema.yaml` do Calamares, o RAGOS deve validar cada domínio do plano de instalação com schema próprio.

---

## Arquitetura alvo para o RAGOS

### Separação entre `uiState` e `installPlan`

O estado do frontend deve ser dividido em dois níveis:

#### `uiState`

Representa apenas estado de experiência e interação:

- abas abertas;
- consultas de busca;
- pino visual do timezone;
- confirmações de checklist local;
- flags temporárias de carregamento.

#### `installPlan`

Representa apenas o contrato instalável, enviado ao backend:

- discos e perfil de storage;
- timezone e locale;
- usuário administrativo;
- interfaces e política WAN;
- hostname;
- parâmetros finais necessários para o executor shell.

### Consequência prática

Campos como estes não devem ser tratados como contrato principal de instalação:

- `timeZonePin`
- `wanIdentified`
- `lanIdentified`
- `destructiveConfirmed`
- `storageProfile`

Esses campos podem continuar existindo na UI, mas não como núcleo do plano persistido.

---

## Plano de implementação por fases

## Fase 1 — contrato formal do plano

### Objetivo

Criar um schema único para o plano de instalação.

### Entregas

- `docs/install-plan-schema.md` com a especificação humana do contrato;
- `installer/installer-ui/src/install-plan.schema.json` como schema técnico;
- alinhamento do backend Rust para refletir esse contrato explicitamente;
- geração futura de tipos para frontend a partir do schema.

### Estrutura sugerida

```text
installPlan
├── localization
├── storage
├── admin
├── network
└── metadata
```

### Exemplo conceitual

- `localization.country`
- `localization.timeZone`
- `storage.diskProfile`
- `storage.selectedDisks`
- `network.wan.mode`
- `network.lan.interface`
- `admin.user`

### Critério de aceite

Frontend, backend e testes passam a validar o mesmo contrato.

---

## Fase 2 — frontend com derivação de plano

### Objetivo

Fazer o React montar o `installPlan` a partir de `uiState`, em vez de usar um objeto híbrido.

### Entregas

- extrair um `deriveInstallPlan(uiState)`;
- extrair `validateInstallPlan(plan)` no frontend;
- reduzir o uso direto do objeto `wizard` como payload;
- deixar [installer/installer-ui/src/pages/Install.jsx](../installer/installer-ui/src/pages/Install.jsx) responsável apenas por enviar `installPlan`.

### Critério de aceite

Toda submissão ao backend ocorre a partir de um plano derivado e validado.

---

## Fase 3 — fluxo declarativo do wizard

### Objetivo

Mover a definição das etapas do wizard para configuração declarativa.

### Entregas

Arquivo sugerido:

```text
installer/installer-ui/src/installer-flow.json
```

Com:

- id da etapa;
- título;
- subtítulo;
- dependências;
- condição de exibição;
- domínio do plano afetado;
- validações necessárias para avanço.

### Exemplo conceitual

- `welcome`
- `eula`
- `localization`
- `timezone`
- `network`
- `disks`
- `users`
- `summary`
- `install`

### Critério de aceite

[installer/installer-ui/src/App.jsx](../installer/installer-ui/src/App.jsx) deixa de ser a fonte única da sequência.

---

## Fase 4 — pipeline semântico de execução

### Objetivo

Quebrar a instalação em estágios explícitos, inspirados na fila de jobs do Calamares.

### Entregas

No backend:

- `preflight`
- `storage-wipe`
- `storage-layout`
- `raid`
- `luks`
- `mount`
- `params`
- `nixos-install`
- `bootloader`
- `finalize`

Cada estágio deve ter:

- nome técnico;
- nome amigável;
- peso;
- início/fim;
- exit code;
- mensagem final.

### Critério de aceite

O frontend passa a renderizar progresso por estágio, e não apenas por stream textual bruto.

---

## Fase 5 — pré-flight técnico obrigatório

### Objetivo

Adicionar uma etapa técnica anterior à execução, semelhante à filosofia de requirements do Calamares.

### Itens a verificar

- quantidade mínima de NICs;
- WAN e LAN não duplicadas;
- compatibilidade entre RAID e quantidade de discos;
- suporte a LUKS/RAID na ISO live;
- timezone e locale coerentes;
- espaço mínimo de disco;
- disponibilidade dos utilitários críticos.

### Critério de aceite

Nenhuma instalação inicia sem pré-flight aprovado.

---

## Fase 6 — presets e perfis operacionais

### Objetivo

Introduzir perfis do instalador com campos travados ou pré-definidos, em linha com a ideia de presets do Calamares.

### Perfis sugeridos

- `gateway`
- `diskless-lab`
- `server-standard`
- `oem-setup`

### Exemplos de uso

- perfil `gateway` força 2 NICs e mostra WAN/LAN;
- perfil `diskless-lab` pode fixar certos parâmetros de rede e storage;
- perfil `oem-setup` reduz campos destrutivos.

### Critério de aceite

O frontend respeita campos bloqueados por perfil e o backend também valida o perfil aplicado.

---

## Estrutura de arquivos sugerida

```text
installer/installer-ui/
├── src/
│   ├── domain/
│   │   ├── installPlan/
│   │   │   ├── deriveInstallPlan.js
│   │   │   ├── validateInstallPlan.js
│   │   │   └── defaults.js
│   │   ├── flow/
│   │   │   └── installer-flow.json
│   │   └── profiles/
│   │       └── installer-profiles.json
│   ├── pages/
│   └── components/
└── src/install-plan.schema.json
```

No backend Rust, a evolução natural é separar [installer/installer-ui/src/main.rs](../installer/installer-ui/src/main.rs) em módulos como:

```text
installer/installer-ui/src/backend/
├── api/
├── plan/
├── validation/
├── execution/
└── runtime/
```

---

## Melhorias diretas de curto prazo

Antes da refatoração total, estas melhorias já trazem benefício imediato:

1. documentar o contrato atual do `PlanRequest`;
2. extrair funções de serialização do payload do frontend;
3. criar testes de paridade entre frontend e backend para campos obrigatórios;
4. mapear campos puramente visuais e removê-los do payload final;
5. padronizar mensagens de erro do backend por domínio.

---

## Riscos e cuidados

### Não perder auditabilidade

O executor shell continua sendo a trilha oficial de instalação. A UI não deve assumir lógica destrutiva por conta própria.

### Não duplicar regra de negócio indefinidamente

Validação duplicada entre React e Rust só é aceitável se ambas vierem do mesmo contrato ou schema.

### Não misturar UX com semântica instalável

Checklist, pin visual, flags de confirmação local e estado de busca devem continuar fora do plano final.

---

## Critério de sucesso

O RAGOS terá absorvido o melhor do Calamares quando atingir os seguintes pontos:

- o wizard for configurável sem reescrever a aplicação;
- o plano de instalação tiver contrato único e validável;
- a execução for mostrada por estágios claros;
- perfis operacionais puderem travar campos e reduzir erro humano;
- frontend, backend, shell installer e documentação falarem a mesma linguagem.

---

## Decisão estratégica

O RAGOS deve evoluir para um instalador com arquitetura inspirada no Calamares, mas mantendo sua identidade técnica:

- **Calamares** como referência de arquitetura modular;
- **React + Rust + shell + NixOS** como stack oficial do projeto.

Essa combinação preserva auditabilidade, simplifica manutenção local e evita dependência direta de Qt/C++ para o produto final do RAGOS.
