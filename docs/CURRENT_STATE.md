# Estado Atual (Current State)

Esta página consolida o estado real e auditado do projeto Kryonix. O que não constar como "Implementado" aqui não existe ou está quebrado no código, devendo ser tratado como [Roadmap](ROADMAP.md).

*Última atualização: Junho 2026*

## Infraestrutura Base
- **Dual-Flake:** Implementado ✅ (Upstream e Downstream isolados corretamente)
- **CI/CD (Cachix + FlakeHub):** Implementado ✅ (Pipelines `ci.yml` e `build.yml` operacionais)
- **Instalador (Backend em Rust):** Parcial 🚧 (Arquitetura Probe→Planner→Backend rodando, porém E2E Install não confirmado 100% livre de Kernel Panics passados)
- **ISO Bootável:** Implementado ✅ (Via `nixosConfigurations.iso`)

## Kryonix Brain (IA / RAG)
- **Módulos NixOS (systemd, ollama, ligthrag):** Implementado ✅ (`modules/nixos/services/brain.nix`)
- **Package Python (kryonix-brain-lightrag):** Implementado ✅ (21 módulos, 25 testes, CLI `rag` funcional)
- **Persistência Estruturada:** Implementado ✅ (Via `kryonix-state.nix` para `/var/lib/kryonix/`)
- **Grafo de Conhecimento (Neo4j):** Implementado ✅ (Via módulo restrito a Tailscale)
- **Sincronização Vault (Obsidian) → RAG:** Parcial 🚧
- **Autopilot / Reasoner:** Roadmap 🛤️

## Model Context Protocol (MCP)
- **Configuração Base (.mcp.json):** Implementado ✅ (Template versionado em `.mcp.example.json`)
- **Filesystem / Read-only:** Parcial 🚧 (wrapper com sandbox implementado; ativação no host ainda não validada)
- **Git / Read-only:** Parcial 🚧 (wrapper com sandbox e allowlist implementado; ativação no host ainda não validada)
- **Sequential Thinking:** Parcial 🚧 (wrapper local sem rede implementado; ativação no host ainda não validada)
- **NixOS Docs MCP:** Parcial 🚧 (pacote Nix sandboxado implementado; ativação no host ainda não validada)
- **GitHub MCP:** Não habilitado ⛔ (token/RBAC e ferramentas mutantes exigem contrato específico)
- **Brain MCP Server:** Parcial 🚧 (Protocolo desenhado, scripts Python existem, mas necessita validação de deploy seguro)
- **Segurança (Políticas, Sandboxing):** Parcial 🚧 (enforcement local implementado; prova de host pendente)

## Desktop & Experiência (Caelestia / Hyprland)
- **Hyprland Core (Wayland):** Implementado ✅
- **KDE Plasma (Alternativa Estável):** Implementado ✅
- **Caelestia Launcher (Live JSON confs):** Implementado ✅ (Usa `user/caelestia/` no downstream)
- **App Wrappers (Performance):** Implementado ✅ (`desktop/hyprland/wrappers.nix`)
- **Aura (Roteador de IA Desktop):** Quebrado ❌ (Depende do `hermes`, que foi aposentado)
- **Kora (Assistente de Voz):** Roadmap / Aposentado 🛤️

## Hosts Downstream Conhecidos
O código upstream expõe profiles para os seguintes hosts que vivem no downstream:
- `glacier` (Server/Brain Node)
- `inspiron` (Workstation/Client Node)
- `inspiron-nina` (Secundário)
