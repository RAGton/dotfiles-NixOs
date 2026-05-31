# Roadmap do Kryonix

Este documento contém o planejamento futuro do projeto Kryonix. O repositório segue rigorosamente o princípio da "Verdade Operacional". Tudo que não possui validação runtime real comprovável encontra-se aqui.

---

## Kryonix Brain API

STATUS: STABLE

DESCRIÇÃO:
API central do Kryonix Brain para centralizar o processamento do LightRAG e LLM operations, abstraindo a IA do host cliente (`inspiron`).

EVIDÊNCIA ATUAL:
- Serviço systemd funcional e persistente: `kryonix-brain-api.service`.
- Porta `8000` ativa e respondendo via Tailscale/LAN no Glacier.
- Endpoint `GET /health` validado.

GAPS:
- Nenhum gap crítico remanescente na infraestrutura de serviço.

CRITÉRIO DE CONCLUSÃO (OBRIGATÓRIO):
- impacto documentado em ARCHITECTURE.md ou USAGE.md
- systemd service `kryonix-brain-api` ativo e em estado `running`.
- porta `8000` aberta em localhost ou LAN.
- endpoint `GET /health` respondendo 200 OK.

COMANDOS DE VALIDAÇÃO:
```sh
systemctl status kryonix-brain-api.service --no-pager
ss -ltnp | grep 8000
curl -sf http://localhost:8000/health
```

RISCOS:
- Inconsistência de acesso concorrente ao banco de vetores.
- Exposição indevida do storage via API HTTP.

---

## MCP Remoto Completo

STATUS: PARTIAL

DESCRIÇÃO:
Suporte pleno ao Model Context Protocol conectando agentes ao Kryonix de forma remota, com discovery automático de ferramentas do servidor.

EVIDÊNCIA ATUAL:
- `kryonix mcp` no CLI está parcialmente implementado em `.mcp.example.json`.
- Tools locais documentadas (mcp-nixos, filesystem).

GAPS:
- Ferramentas de servidor (como `rag_search` e `graph_heal`) não foram validadas no runtime do Glacier via MCP.
- Sem comprovação de conexão segura persistente entre Inspiron e a sessão SSH que inicializa o MCP do Brain.

CRITÉRIO DE CONCLUSÃO (OBRIGATÓRIO):
- impacto documentado em ARCHITECTURE.md ou USAGE.md
- O CLI `kryonix mcp doctor` retornar status OK (sem falhas de timeout ou paths incorretos) validando o servidor do Glacier.
- Retorno JSON-RPC com as `tools` ativas na interface do Claude/Cursor.

COMANDOS DE VALIDAÇÃO:
```sh
kryonix mcp doctor
kryonix mcp check
```

RISCOS:
- Vazamento de secrets no JSON-RPC.
- Timeout no boot-up do virtualenv/python via SSH.

---

## Glacier NixOS Definitivo (Autônomo)

STATUS: STABLE

DESCRIÇÃO:
Consolidação do Glacier como backend headless autônomo. O gerenciamento das cargas de inteligência deve inicializar automaticamente independente do login gráfico.

EVIDÊNCIA ATUAL:
- Host profile presente em `hosts/glacier`.
- `ollama.service` funcional.
- Inicialização autônoma via SSH/Tailscale validada.

GAPS:
- Nenhum gap de autonomia operacional identificado.

CRITÉRIO DE CONCLUSÃO (OBRIGATÓRIO):
- impacto documentado em ARCHITECTURE.md ou USAGE.md
- O Glacier conseguir inicializar e servir `Ollama`, `Tailscale` e `Brain API` sem necessidade de login manual (apenas boot).

COMANDOS DE VALIDAÇÃO:
```sh
kryonix test server
```

RISCOS:
- Dependência de montagem de drives criptografados manuais que impedem serviços no boot.

---

## Web Research Controlado

STATUS: NOT_IMPLEMENTED

DESCRIÇÃO:
Agentes locais com acesso seguro à internet para pesquisa e ingestão, rodando sob restrições de rede e sandbox rigorosas.

EVIDÊNCIA ATUAL:
- Nenhuma ferramenta MCP de web-search ativa.
- Nenhum container ou `bwrap` isolado para o RAG web scrape atrelado.

GAPS:
- Todo o pipeline de ingestão e parse de HTML para Markdown do LightRAG na nuvem local.

CRITÉRIO DE CONCLUSÃO (OBRIGATÓRIO):
- impacto documentado em ARCHITECTURE.md ou USAGE.md
- Serviço / CLI atrelado ao `kryonix brain ingest-web <url>` funcional.
- Sandboxing efetivo comprovado na extração.

COMANDOS DE VALIDAÇÃO:
```sh
kryonix brain ingest-web "https://nixos.org"
```

RISCOS:
- Scraping executado como processo não-sandbox, abrindo brechas de injeção direta no Vault/Graph.

---

## Geração de Pacotes com IA

STATUS: NOT_IMPLEMENTED

DESCRIÇÃO:
Pipelines LLM injetando de forma autônoma receitas ou scripts Nix na flake para empacotar softwares não mantidos pelo upstream.

EVIDÊNCIA ATUAL:
- Nada presente no repositório.

GAPS:
- Infraestrutura completa de review, syntax-check automático e git-commit via agentes.

CRITÉRIO DE CONCLUSÃO (OBRIGATÓRIO):
- impacto documentado em ARCHITECTURE.md ou USAGE.md
- Agente ser capaz de criar um `.nix` novo, formatar via `nix fmt` e aprovar em `nix flake check`.

COMANDOS DE VALIDAÇÃO:
```sh
kryonix agent package-gen "nome-do-pacote"
```

RISCOS:
- Corrupção da flake inteira por geração arbitrária de arquivos `default.nix`.

---

## Autocuradoria do Vault

STATUS: NOT_IMPLEMENTED

DESCRIÇÃO:
Processos automáticos do Brain avaliando e reorganizando notas no Vault baseados na relevância, deletando documentação obsoleta internamente.

EVIDÊNCIA ATUAL:
- A CLI `kryonix vault scan` apenas reporta integridade básica.

GAPS:
- Nenhum job assíncrono indexando metadados de stale notes.

CRITÉRIO DE CONCLUSÃO (OBRIGATÓRIO):
- impacto documentado em ARCHITECTURE.md ou USAGE.md
- Comando CLI ou timer systemd validando e listando notas marcadas para deleção via LLM.

COMANDOS DE VALIDAÇÃO:
```sh
kryonix vault curate --dry-run
```

RISCOS:
- Destruição de conhecimento permanente devido à alucinação de irrelevância pela LLM.

---

## ISO Instalável Kryonix

STATUS: IN_PROGRESS

DESCRIÇÃO:
Sistema de build em CI/CD ou local para gerar uma ISO standalone (USB bootable) para deploy da distro Kryonix.

EVIDÊNCIA ATUAL:
- **Motor de Instalação (Rust):** Implementado em `packages/kryonix-installer`.
- **Autosave Resiliente:** Watcher com debounce e validação JSON para persistência no downstream `/etc/kryonixos`.
- **Disk Planner:** Geração dinâmica de `disks.nix` via Disko (BTRFS + Subvolumes) e execução via API.
- **Orquestrador:** Fluxo completo `disko` + `nixos-install` integrado no backend.
- **Profile Selector:** Interface para aplicação de perfis (Gamer, Dev) via patching de AST/Strings no Nix.
- **Live ISO:** Host profile em `hosts/iso` funcional com desktop básico.

GAPS (Próximos Passos):
- UX Inteligente: Detecção de repositório existente e modo de restauração.
- Polimento Live: Splash screen (Plymouth), GRUB/UEFI hardening e Kiosk Mode.
- Validação VM: Script de teste automatizado via QEMU/KVM.

CRITÉRIO DE CONCLUSÃO (OBRIGATÓRIO):
- Comando CLI conseguir gerar um arquivo `kryonix.iso`.
- Instalação ponta-a-ponta em VM validada com bootloader funcional.

COMANDOS DE VALIDAÇÃO:
```sh
kryonix build iso
./scripts/test-iso-boot.sh
```

---

## Pipeline de sincronização docs → vault → Brain/RAG

STATUS: NOT_IMPLEMENTED

DESCRIÇÃO:
Criação de um comando integrado na CLI `kryonix vault sync-docs` para automatizar a derivação de notas do vault a partir da documentação canônica em `docs/`, garantindo que o RAG esteja sempre atualizado com a fonte de verdade operacional.

CRITÉRIO DE CONCLUSÃO (OBRIGATÓRIO):
- Comando `kryonix vault sync-docs` funcional.
- Metadados de sincronização (last_sync) inseridos automaticamente.
- Verificação de divergências entre `docs/` e `01-Canonical/`.

COMANDOS DE VALIDAÇÃO:
```sh
kryonix vault sync-docs
```

---

## Milestones

### 🏁 v0.4.2 - Stabilization & Governance
**Status: DONE (100%)**
- [x] #14 — CI Hardening (Nix, Shell, Rust, Python, Secrets)
- [x] #15 — Auditoria de Licença (Source Available)
- [x] #16 — Auditoria de Docs/Links
- [x] #13 — Auditoria e resolução de PRs abertos

### 🚀 v0.5.0 - Glacier & Brain API
**Status: DONE (100%)**
- [x] #17 — Benchmark Ollama (RTX 4060)
- [x] #19 — Kryonix Brain API (Persistência, Health e VRAM Profiles)
- [x] #21 — Autonomia Plena do Glacier (VRAM Profiles e Safe Deploy)
- [x] #27 — Resilient Autosave & Caelestia Hybrid Mode

### 📦 v0.6.0 - ISO & IA Autônoma
**Status: EM EXECUÇÃO (60%)**
- [x] #25 — Finalizar ISO Instalável (Backend & Core Orchestration)
- [ ] #28 — Refinamento UX Instalador (Automatic Detection & Manual Mode)
- [ ] #29 — Polimento Live Environment (Plymouth, Kiosk, GRUB)
- [x] #30 — CI/CD para ISO (GitHub Actions + Boot Test)
- [ ] #22 — Web Research para Agentes
- [ ] #23 — Pipeline de Geração de Receitas/Pacotes Nix
- [ ] #24 — Autocura e Reorganização do Vault
- [ ] #26 — Sincronização Doc -> Vault -> RAG
- [ ] #18 — [P1][home-brain] Fechar Autopilot seguro (UNSTABLE)
