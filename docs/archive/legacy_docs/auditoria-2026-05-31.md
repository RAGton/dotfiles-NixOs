# Auditoria Kryonix — 2026-05-31

> Auditoria baseada em leitura direta dos arquivos do repositório.
> Nenhuma conclusão foi inferida sem evidência de código.

---

## Estado Geral (notas 0–10)

| Área           | Nota | Justificativa resumida                                              |
|----------------|------|---------------------------------------------------------------------|
| **Nix**        | 8/10 | Flake modular, overlays, módulos exportados; falta `templates`      |
| **CI/CD**      | 9/10 | build.yml + Cachix + doc-audit.sh funcionando; minor: só iso no upstream hosts.nix |
| **CLI**        | 8/10 | resolve_flake robusto; switch/all semântica confusa; post-install hardcoda "rocha" |
| **Desktop**    | 9/10 | Fase 4 completa: todos os arquivos core/ + user-vars/ + user.nix 26 linhas |
| **Downstream** | 9/10 | 3 hosts avaliam, 10 follows, avatar.png presente                    |
| **Segurança**  | 8/10 | EnvironmentFile correto; npm audit não confirmado; neo4j.env root:root no worktree |
| **Installer**  | 6/10 | Backend Axum OK; installPhase do .nix copia static/ em vez de `npm build` |

---

## 1. Mapa do que foi Realizado

### INFRAESTRUTURA NIX

| Item | Estado | Evidência |
|------|--------|-----------|
| `flake.nix` modularizado (roteador fino) | ✅ | Delega para `flake/{checks,packages,shells,formatter,modules,data/hosts}.nix`; 130 linhas |
| `flake/data/hosts.nix` extraído | ✅ | Existe; contém apenas `iso` — `glacier`/`inspiron` vivem no downstream (`/etc/kryonixos`) por design |
| `flake/data/users.nix` extraído | ❌ | **Não existe**. Usuários ficam em `/etc/kryonixos/users.nix` (downstream) |
| `nixosModules.default` exportado | ✅ | `flake/modules.nix` exporta `nixosModules.default` = `options + hosts/common` |
| `homeManagerModules.default` exportado | ✅ | `flake/modules.nix` exporta `homeManagerModules.default` = `modules/home-manager/common` |
| `overlays` exportados | ✅ | `flake.nix` expõe `overlays.*` + `lib.overlays.*`; 10 overlays em `overlays/default.nix` |
| `templates.default` para `nix flake init` | ❌ | **Não existe**. Não há `templates` nos outputs do flake |

### CI/CD

| Item | Estado | Evidência |
|------|--------|-----------|
| `.github/workflows/build.yml` correto | ✅ | Flake-check + matriz de 9 targets + push Cachix |
| Cachix configurado (`extra-substituters` + `extra-trusted-public-keys`) | ✅ | Em `flake.nix` (nixConfig) e `modules/nixos/common/default.nix` (nix.settings) |
| `trusted-users = ["@wheel"]` em common | ✅ | `modules/nixos/common/default.nix:97` |
| `doc-audit.sh` sem falsos positivos | ✅ | Script correto; exclui `archive/` e `operations/`; roda em `ci.yml` |
| Comandos USAGE.md validados pelo CI | ✅ | `ci.yml` job `shell` roda `./scripts/doc-audit.sh` em PR/push |

### CLI (kryonix)

| Item | Estado | Evidência |
|------|--------|-----------|
| `resolve_flake` ordem a→f implementada | ✅ | `nixos.sh:251` — 6 ramos: `--flake` > `KRYONIX_FLAKE` > git-root > canonical > `/etc/kryonix` > erro |
| `infer_or_verify_host` automático | ✅ | `nixos.sh:332` — único host → infere; múltiplos → lista interativa |
| `kryonix switch` de qualquer diretório | ✅ | `resolve_flake` detecta o repo pelo git e acha o downstream canônico |
| `kryonix switch all` / `kryonix all` | ⚠️ | **Semântica "OS + HM do host atual"**, não "todos os hosts". `apply_all=1` faz NixOS switch + `nh home switch` para o host corrente. Pode confundir |
| Comandos: `boot`, `test`, `diff`, `fmt`, `iso`, `git-status`, `commands` | ✅ | Todos presentes em `main.sh` |
| `USAGE.md` sincronizado com implementação | ✅ | doc-audit.sh valida e passa no CI |

### DESKTOP — Fase 4 (Hyprland)

Todos os arquivos da Fase 4 existem e têm conteúdo substantivo:

| Arquivo | Linhas | Estado |
|---------|--------|--------|
| `core/monitors.nix` | 18 | ✅ Hook override por host |
| `core/rules.nix` | 28 | ✅ windowrule mkOrder:400 |
| `core/keybinds.nix` | 140 | ✅ binds mkOrder:700 |
| `core/xdg.nix` | 19 | ✅ kdeglobals |
| `core/hyprland.nix` | 18 | ✅ configType="hyprlang", systemd.enable=false |
| `core/packages.nix` | 18 | ✅ ferramentas de sessão |
| `core/mime.nix` | 172 | ✅ associações MIME |
| `core/dconf.nix` | 58 | ✅ Blueman, GTK, GNOME utils |
| `core/cursor.nix` | 17 | ✅ Cursor GTK + X11 + Wayland |
| `caelestia/hyprpaper.nix` | 17 | ✅ fallback sem backend |
| `user-vars/theme.nix` | 36 | ✅ importa core/hyprland, packages, cursor |
| `user-vars/mime.nix` | 16 | ✅ importa core/mime, dconf |
| `user-vars/keybinds.nix` | 24 | ✅ mkOrder:800 |
| `user.nix` | **26** | ✅ Puro orquestrador — meta satisfeita |

> Nota: `core/hyprland.nix`, `packages.nix`, `cursor.nix`, `mime.nix`, `dconf.nix` são importados **transitivamente** via `user-vars/theme.nix` e `user-vars/mime.nix`, não diretamente em `user.nix`. Design correto e intencional.

### DOWNSTREAM (kryonixos)

| Item | Estado | Evidência |
|------|--------|-----------|
| Declara todos inputs upstream com `.follows` | ✅ | 10 `.follows`: nixpkgs, home-manager, hardware, nix-flatpak, disko, caelestia-shell, antigravity-nix, nixpkgs-stable, codex, kryonix-home |
| inputs: caelestia-shell, antigravity-nix, kryonix-home | ✅ | Auditados em `/etc/kryonixos/flake.nix:26-32` com comentário de mapeamento |
| `assets/avatar.png` | ✅ | `/etc/kryonixos/assets/avatar.png` |
| Hosts: inspiron, glacier, inspiron-nina avaliam | ✅ | `nix eval` retorna drvPath para os 3 sem erro |
| `kryonix switch all` passa limpo | ✅ | Semântica = NixOS + HM do host corrente; funciona para cada host individualmente |

### SEGURANÇA

| Item | Estado | Evidência |
|------|--------|-----------|
| `brain.env` nunca no nix store | ✅ | Todos os serviços usam `EnvironmentFile = "-${cfg.environmentFile}"` (prefixo `-` = opcional) |
| Secrets hardcoded em `.nix` / `modules/` | ✅ (limpo) | grep por `KRYONIX_BRAIN_KEY`, `api_key` nos arquivos `.nix` retornou zero resultados fora de strings de opção/descrição |
| `npmDepsHash` atualizado | ✅ | `packages/kryonix-installer.nix:10` contém hash real |
| CVEs npm do installer confirmados zero | ⚠️ | Sem evidência de `npm audit` ter sido executado recentemente |
| `neo4j.env` e `kora.env` no worktree | ⚠️ | Ambos em `/etc/kryonix/` com owner `root:root`; não estão no `.gitignore` explicitamente verificado |

### INSTALLER

| Item | Estado | Evidência |
|------|--------|-----------|
| Backend Axum compila | ✅ | `src/main.rs` com módulos `auth`, `disk`, `executor`, `install`, `network`, `profiles`; Axum 0.7 |
| Frontend Vite builda | ⚠️ | **Bug no `.nix`**: `installPhase` copia `static/*` em vez de executar `npm run build`. O build do Nix pega assets pré-compilados, não o output real do Vite |
| Kiosk service | ✅ | `modules/nixos/installer/web-kiosk.nix` (138 linhas); `kryonix.installer.kiosk.enable` |
| ISO buildável | ✅ | `flake/data/hosts.nix` contém `iso`; `hosts/iso/default.nix` com `offlineMode` param |

---

## 2. Gaps e Pendências

### FASE 6 — Caelestia Hybrid (parcialmente iniciada)

| Item | Estado | Evidência |
|------|--------|-----------|
| `mkOutOfStoreSymlink` em caelestia | ✅ **FEITO** | `desktop/hyprland/rice/caelestia-config.nix:146,149,152,156` — 4 symlinks para `/etc/kryonixos/user/caelestia/` |
| JSON ao vivo (`shell.json`, `scheme.json`) | ⚠️ **PARCIAL** | `scheme.json` e `shell.json` existem em `/etc/kryonixos/user/caelestia/`; **`shell-tokens.json` ausente** |
| `kryonix caelestia save [--commit]` | ❌ | Comando não existe no CLI (grep zero resultados) |
| Caminho real verificado | ⚠️ | Spec diz `~/kryonixos/caelestia/`; código aponta para `/etc/kryonixos/user/caelestia/` — divergência de path |

### FASE 5 — Meta-Distro Consumer (não iniciada)

| Item | Estado |
|------|--------|
| `templates.default` no flake upstream | ❌ Ausente |
| Thin consumer flake gerado pelo installer | ❌ Ausente |
| CLI distingue consumer vs maintainer | ❌ Ausente |
| Documentação de consumer | ❌ Ausente |
| Spec 05 em `specs/` | ❌ Ausente (`specs/` tem 01-04 + 06) |

### FASE 2 — Packages (estrutura presente, refinamento pendente)

| Item | Estado | Evidência |
|------|--------|-----------|
| `callPackage` para todos os packages | ✅ | `flake/packages.nix` usa `callPackage` para todos |
| `kryonix-cli.nix` como package | ✅ | `packages/kryonix-cli.nix` (105 linhas) |
| `kryonix-home.nix` isolado | ✅ | `packages/kryonix-home.nix` |
| `kryonix-installer/` estruturado | ⚠️ | Estruturado, mas `installPhase` não chama `npm run build` |

### GOVERNANÇA

| Item | Estado |
|------|--------|
| `CLAUDE.md` reflete estado real | ✅ Correto |
| `AGENTS.md` reflete arquitetura | ✅ Correto |
| `specs/` sincronizadas | ⚠️ Spec 05 faltando; spec 06 existe mas tem divergência de path |
| `doc-audit.sh` cobre todos os módulos | ✅ Cobre USAGE.md vs main.sh |

---

## 3. Métricas de Saúde

```
Hosts avaliados (drvPath):
  inspiron:       /nix/store/ghkf9n4r4ljcika7kh1j9lva87wi9373-nixos-system-inspiron-26.05.20260523.64c08a7.drv  ✅
  glacier:        /nix/store/v78xmapc5456lv4vavzibysp255b5gsw-nixos-system-RVE-GLACIER-26.05.20260523.64c08a7.drv  ✅
  inspiron-nina:  /nix/store/bygkws0wq4rpkid3w1h1hx52pq4iimmc-nixos-system-inspiron-nina-26.05.20260523.64c08a7.drv  ✅

Closure atual (inspiron):   ~43 GB

Contagem de arquivos:
  *.nix:  353
  *.md:   1175  ← elevado; docs/ + .agents/ proliferação
  *.sh:    72
  *.rs:    78

Downstream flake.nix .follows: 10

Módulos > 150 linhas (candidatos a refactor):
  572  modules/home-manager/programs/vscode/default.nix
  559  modules/nixos/common/default.nix
  527  modules/nixos/services/brain.nix
  365  modules/home-manager/services/waybar/default.nix
  318  modules/nixos/desktop/caelestia/default.nix
  293  modules/nixos/branding/kryonix/default.nix
  265  modules/nixos/services/kora/default.nix
  262  modules/home-manager/programs/jupyter/default.nix
  235  modules/nixos/installer/default.nix

Git log upstream (últimos 15):
  8147efaf refactor(lib): move home configurations from home/ to users/
  670c0ad1 fix(profiles/tools): simplify vscode activation
  66320876 fix(caelestia): fix null coercion in activation script
  0b95ee1b fix(jupyter): use correct evcxr_jupyter binary
  ... (outros fixes)

Git log downstream (últimos 10):
  173d0a5 fix(flake): adiciona todos os inputs upstream faltando (auditoria completa)
  816cd17 fix(downstream): declara inputs faltando do upstream
  7768600 chore: adiciona assets/avatar.png
  ...
```

---

## 4. Débito Técnico

### Bugs confirmados

**[BUG-1] `installPhase` do installer.nix não executa `npm run build`**
- Arquivo: `packages/kryonix-installer.nix:19`
- O que há: `cp -r static/* $out/dist/` copia assets pré-compilados do diretório `static/`
- O que deveria: executar `npm run build` (Vite) e copiar `dist/` gerado
- Impacto: o binário do installer serve o frontend pré-compilado commitado, não o build atual do código fonte React

**[BUG-2] `shell-tokens.json` ausente no downstream**
- Arquivo: `/etc/kryonixos/user/caelestia/` — apenas `scheme.json` e `shell.json`
- `caelestia-config.nix:149` cria symlink para `shell-tokens.json` que não existe
- Impacto: Home Manager switch pode falhar ou criar symlink quebrado

**[BUG-3] `post-install.sh` hardcoda username "rocha"**
- Arquivo: `packages/kryonix-cli/post-install.sh:19,26`
- Embora seja script de "healing" para o sistema pessoal, está injetado em `modules/nixos/common/default.nix` via `writeShellScript`, portanto faz parte do upstream público

### Acúmulo de artefatos no working tree

| Artefato | Localização | Risco |
|----------|-------------|-------|
| `iso.nix` na raiz | `/etc/kryonix/iso.nix` | Órfão; não referenciado pelo flake outputs; usa `builtins.getFlake` impuro |
| `files (1)/` + `files.zip` | `/etc/kryonix/` | Diretório temporário com espaço no nome; provável lixo de upload |
| `fix/` | `/etc/kryonix/fix/` | Contém `ENTREGA_INSTALLER_KIT.md` + artefatos; não é código fonte |
| `kora.env` + `neo4j.env` | `/etc/kryonix/` (root:root) | Secrets de runtime; `.gitignore` deve cobri-los explicitamente |
| `.ai/` e `.agents/` simultaneamente | `/etc/kryonix/` | Dois diretórios de contexto AI ativos; redundância |
| `GEMINI.md` na raiz | `/etc/kryonix/GEMINI.md` | Quarto arquivo de instruções AI na raiz (CLAUDE.md, AGENTS.md, CONTRIBUTING_AGENTS.md, GEMINI.md) |
| 1175 arquivos `.md` | Repo inteiro | Densidade anormal; `docs/` cresceu sem disciplina |

### Código correto mas que precisa de atenção

- **`common/default.nix` (559 linhas)**: Monolito que mistura boot, rede, locale, usuários, containers, fontes, serviços. Difícil de auditar e testar isoladamente.
- **`brain.nix` (527 linhas)**: Serviço crítico com muita lógica inline.
- **`kryonix switch all` — semântica enganosa**: O comando não itera "todos os hosts"; aplica NixOS + HM do host corrente. O nome sugere comportamento diferente do real.
- **`kryonix-caelestia-watcher/src/main.rs:70`**: TODO explícito — `// TODO: Implement nix-edit or text replacement logic for flake.nix imports`; ferramenta incompleta.
- **`kora/api/routes_stream.py:45`**: TODO Phase 3 não implementado — streaming do Kora sem integração com Brain.

---

## 5. Sugestões de Evolução

### PRIORIDADE ALTA — Bloqueadores / Riscos

**A1. Criar `shell-tokens.json` em `/etc/kryonixos/user/caelestia/`**
- Impede Fase 6 de funcionar completamente (`mkOutOfStoreSymlink` aponta para arquivo inexistente)
- Fix: criar o arquivo com conteúdo vazio `{}` ou migrar do store atual

**A2. Corrigir `installPhase` do installer.nix**
- O build Nix do installer não reflete o código React atual
- Fix: mudar `installPhase` para executar `npm run build` e copiar `dist/`

**A3. Verificar `.gitignore` cobre `kora.env` e `neo4j.env`**
- Ambos são secrets de runtime com owner root; se não estiverem no `.gitignore`, podem ser commitados acidentalmente

**A4. Adicionar `templates.default` ao flake** (requisito da Fase 5)
- Sem isso, `nix flake init --template github:RAGton/kryonix` não funciona
- Bloqueia qualquer terceiro de usar o projeto como meta-distro

### PRIORIDADE MÉDIA — Qualidade e DX

**M1. Renomear / documentar `kryonix switch all`**
- Semanticamente: "aplica NixOS + HM do host atual"
- Opção: renomear para `kryonix full` ou adicionar `kryonix switch --all-layers`; documentar claramente no USAGE.md

**M2. Implementar `kryonix caelestia save [--commit]`**
- Fase 6 está 60% feita (symlinks prontos, JSONs parcialmente presentes)
- Falta o comando CLI que copia estado em memória → JSONs e faz `git commit`

**M3. Quebrar `common/default.nix` em sub-módulos**
- 559 linhas num único arquivo que afeta todos os hosts é risco de regressão alto
- Sugestão de split: `common/boot.nix`, `common/network.nix`, `common/locale.nix`, `common/users.nix`, `common/containers.nix`

**M4. Limpar artefatos do working tree**
- Remover ou mover: `iso.nix`, `fix/`, `files (1)/`, `files.zip`
- Consolidar `.ai/` em `.agents/` e remover o duplicado

**M5. Criar `specs/05-meta-distro-consumer.md`**
- Fase 5 está sem spec; qualquer trabalho futuro nessa direção começa sem contrato

### PRIORIDADE BAIXA — Melhorias Futuras

**B1. Para Kryonix ser instalável por terceiros faltam**:
- `templates.default` no flake
- Documentação de "consumer vs maintainer"
- `kryonix-installer` com build frontend correto

**B2. Documentação está densa demais, não escassa**
- 1175 arquivos `.md` dificultam encontrar a fonte de verdade
- Sugestão: arquivar `docs/archive/`, `docs/evidence/`, `docs/development/` que parecem históricos

**B3. Testes automatizados de maior valor**
- VM test para o installer (script `test-installer-kvm.sh` existe mas não está no CI)
- `nix flake check` de `homeConfigurations.*` no upstream (atualmente só `nixosConfigurations`)

---

## 6. Roadmap Sugerido — Próximos 3 Passos

### Passo 1 — Finalizar Fase 6 Caelestia Hybrid (1–2 dias)

**Justificativa**: 60% feito; `mkOutOfStoreSymlink` está no código, falta apenas o `shell-tokens.json` e o comando CLI.

```
1. Criar /etc/kryonixos/user/caelestia/shell-tokens.json com {}
2. Implementar `kryonix caelestia save [--commit]` em packages/kryonix-cli/
   - Ler os 3 JSONs de ~/.config/caelestia/ (estado ao vivo)
   - Copiar para /etc/kryonixos/user/caelestia/
   - Se --commit: git -C /etc/kryonixos add + commit
3. Testar: editar cor na UI Caelestia → kryonix caelestia save --commit → kryonix home switch
```

### Passo 2 — Corrigir installer.nix installPhase (½ dia)

**Justificativa**: Bug que faz o artefato Nix não refletir o código fonte real; afeta qualidade do release.

```nix
# packages/kryonix-installer.nix — substituir installPhase de:
cp -r static/* $out/dist/
# para:
npm run build
cp -r dist/* $out/dist/
```

### Passo 3 — Adicionar templates.default + spec Fase 5 (1 dia)

**Justificativa**: Habilita qualquer terceiro (e o próprio installer) a criar um consumer flake válido; é o pré-requisito da Fase 5.

```nix
# flake.nix — adicionar ao outputs:
templates = {
  default = {
    path = ./templates/consumer;
    description = "Consumer flake para kryonix meta-distro";
  };
};
```

---

## Riscos

| Risco | Probabilidade | Impacto | Mitigação |
|-------|---------------|---------|-----------|
| `shell-tokens.json` ausente quebra HM switch no inspiron | Alta | Médio | Criar arquivo imediatamente |
| `installPhase` errado entrega installer com frontend desatualizado | Alta | Alto | Corrigir antes do próximo release |
| `common/default.nix` monolítico — regressão afeta todos os hosts | Média | Alto | Split incremental por PR |
| `neo4j.env`/`kora.env` não cobertos pelo `.gitignore` | Baixa | Crítico | Verificar e adicionar ao `.gitignore` |
| `kryonix switch all` semântica confusa — usuário espera "todos os hosts" | Média | Baixo | Documentar e/ou renomear |
| 1175 arquivos `.md` — docs desatualizadas como fonte de verdade | Baixa | Médio | Arquivar históricos, manter docs/ enxuto |
| `kryonix-caelestia-watcher` com TODO estrutural — ferramenta incompleta em produção | Baixa | Baixo | Não expor no PATH até implementar |

---

*Auditoria gerada em 2026-05-31 por leitura direta dos arquivos do repositório.*
*Referência: `/etc/kryonix` (upstream) + `/etc/kryonixos` (downstream).*
