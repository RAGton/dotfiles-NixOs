# Kryonix Roadmap

Este documento lista os próximos passos e metas do projeto Kryonix. O foco atual (v0.6.0) é a maturidade do Model Context Protocol (MCP) e consolidação da infraestrutura de IA.

## Milestone v0.6.0: Era MCP & Agentic Workflows
*Status Atual: Em Progresso (60%)*

### 1. Documentação Canônica & Memória IA (Você está aqui)
- [x] Limpar doc sprawl (documentação desatualizada e fragmentada).
- [x] Estabelecer arquitetura Dual-Flake claramente na documentação.
- [x] Atualizar contexto de IA (`docs/ai/`).

### 2. Infraestrutura MCP (Model Context Protocol)
- [x] Implementar wrappers sandboxados para Filesystem, Git, NixOS Docs e Sequential Thinking.
- [ ] Ativar e validar os wrappers MCP no host cliente.
- [ ] Definir RBAC e escopo read-only antes de reconsiderar MCP GitHub.
- [ ] Validar e fazer deploy seguro do servidor MCP nativo do `kryonix-brain`.
- [ ] Ativar MCP Neo4j (Read-only).
- [ ] Ativar MCP Ollama.

### 3. Integração Contínua & Segurança
- [x] Configuração Cachix + GitHub Actions.
- [x] Bloqueio automático de secrets (Gitleaks).
- [ ] Teste E2E automatizado da imagem ISO.

---

## Milestone v0.7.0: Autopilot & GraphRAG Ativo

### 1. Raciocínio (Autopilot)
- [ ] Implementar loop de pensamento (reasoning) nativo em `kryonix-brain-lightrag`.
- [ ] Integração com Modelos de Raciocínio Locais ou via API Segura.

### 2. Gestão de Conhecimento
- [ ] Indexação automática de documentos novos no Obsidian.
- [ ] Melhorias no processo de extração do Neo4j para RAG.
- [ ] Autocura de conhecimento.

---

## Milestone v0.8.0: Desktop Experience (Caelestia V2)

- [ ] Remoção completa da dependência do módulo `hermes` obsoleto.
- [ ] Novo roteador de inteligência (`aura`) funcional.
- [ ] Otimização profunda do Hyprland (remoção de stutters e redução de uso de GPU em efeitos de blur).
- [ ] Integração do Caelestia Launcher com a busca nativa do Brain.

---

## Backlog / Futuro
- **Kora Voice Assistant:** Reescrever stack de voz para operação local estável.
- **Home Assistant MCP:** Integração profunda de automação residencial aos agentes.
- **Proxmox MCP:** Automação de infraestrutura virtual a partir dos agentes.
