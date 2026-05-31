---
name: prompt-engineering
description: Cria prompts seguros e completos para agentes que operam ou modificam o kryonix — define contexto do repositório, escopo, arquivos obrigatórios de leitura, regras operacionais, validações, riscos e rollback. Use quando precisar criar um prompt para qualquer agente (Copilot, Codex, Gemini, Antigravity) que vá modificar código, NixOS, Brain, RAG, modules, packages, scripts ou documentação do kryonix.
---

# Skill: Prompt Engineering para Agentes Kryonix

## Objetivo

Estabelecer padrões profissionais e seguros para criação de prompts destinados a agentes (Copilot, Codex, Gemini, Antigravity e demais LLMs) que irão operar ou modificar partes do projeto Kryonix. Garante que cada prompt forneça contexto completo, regras operacionais rígidas, escopo claro, arquivos obrigatórios para leitura, validações, riscos, rollback e critérios de conclusão.

## Quando usar

- Criação de prompts para agentes que modificam código, NixOS, Brain, RAG, GraphRAG, MCP, Home Manager, modules, profiles, features, overlays, packages, scripts, documentação ou fluxos do Kryonix.
- Delegação de tarefas técnicas para qualquer agente externo.
- Onboarding de novo agente no repositório.
- Qualquer operação que envolva alteração no repositório via LLM.

## Escopo

- Criação de prompts avançados e completos.
- Padrão unificado para todos os agentes.
- Estrutura obrigatória para prompts seguros.
- Prevenção de comportamentos destrutivos.
- Proteção contra invenção de recursos ou comportamentos inexistentes.

---

## Estrutura Obrigatória

Todo prompt gerado por esta skill deve conter **todas** as seções abaixo:

### 1. Contexto do Repositório
```
Você está operando na plataforma Kryonix, um sistema NixOS declarativo
multi-host baseado em Flakes.
Repositório: https://github.com/ragton/kryonix
Caminho operacional: /etc/kryonix
```

### 2. Objetivo específico
O que deve ser alcançado, com escopo preciso.

### 3. Escopo permitido
Lista explícita de arquivos e diretórios que o agente pode modificar.

### 4. Fora de escopo
Lista explícita do que o agente NÃO pode modificar. Inclui sempre:
- Storage do usuário, `.ssh/`, `.gnupg/`, `.env` reais
- Boot, rede, GPU, storage, firewall, SSH, secrets (sem plano explícito)
- Permissões de host, Tailscale, serviços críticos

### 5. Arquivos obrigatórios para leitura
O agente deve ler **antes** de qualquer alteração:
- `AGENTS.md`
- `.agents/rules/00-core.md`
- `.agents/rules/90-definition-of-done.md`
- `flake.nix`
- `hosts/<host>/default.nix`
- `.context/CURRENT_STATE.md`
- `docs/ai/PROJECT_CONTEXT.md`
- Módulos/arquivos diretamente afetados pela tarefa
- Documentação relevante em `docs/`

### 6. Fonte de verdade
```
O código do repositório é a fonte de verdade.
Nunca inventar módulos, comandos, serviços ou paths.
Documentação antiga é auxiliar, não autoritativa.
```

### 7. Regras obrigatórias
- O agente deve ler o repo antes de alterar.
- Nunca usar `git add .`.
- Commits pequenos, temáticos e explícitos.
- Nunca alterar boot, rede, GPU, storage, firewall, SSH ou secrets sem plano, riscos e rollback.
- Usar CLI `kryonix` quando existir equivalente.
- Dry-run antes de apply para operações destrutivas.
- Nunca inventar paths, módulos ou hosts.
- Toda mudança deve ser validada antes de declarar pronta.

### 8. Comandos de diagnóstico
```bash
cd /etc/kryonix
git status --short
git diff --stat
git diff --check
```

### 9. Comandos de validação
```bash
# NixOS
kryonix fmt
kryonix check --host <host>
nix flake check --keep-going

# Build
nix build .#nixosConfigurations.<host>.config.system.build.toplevel --no-link
kryonix rebuild --host <host>

# Home Manager
kryonix home --host <host>

# Brain/RAG/MCP
kryonix brain health
kryonix brain stats
kryonix mcp check

# Pacote específico
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test --all
nix build .#<package> --no-link
```

### 10. Plano de execução
Passos numerados e sequenciais que o agente deve seguir.

### 11. Riscos
Lista de riscos concretos associados à tarefa. Sempre incluir:
- Agentes realizando mudanças sem ler o código
- Criação de recursos não existentes
- Alterações em múltiplos hosts sem isolamento
- Quebra de boot, rede, GPU ou armazenamento
- Perda de acesso ao Glacier
- Exposição de secrets

### 12. Rollback
Procedimento de reversão para cada risco identificado.

### 13. Critérios de conclusão
Condições verificáveis que determinam quando a tarefa está completa.

---

## Regras para o Agente que Gera Prompts

- Não pode escrever prompts simplistas ou sem estrutura.
- Não pode remover seções obrigatórias do modelo.
- Não pode permitir alterações sem validação.
- Não pode suprimir avisos de risco.
- Não pode inventar paths, módulos ou hosts.
- Deve sempre incluir comandos reais do Kryonix.
- Deve adaptar as seções ao contexto da tarefa sem omitir nenhuma.

---

## Template Base

```markdown
# Prompt para Agente — [Título da Tarefa]

## 0. Contexto do Repositório
Você está operando na plataforma **Kryonix**, um sistema NixOS declarativo
multi-host baseado em Flakes.
Repositório: https://github.com/ragton/kryonix
Caminho operacional: `/etc/kryonix`

## 1. 🎯 Objetivo
[Descrição precisa do que deve ser alcançado]

## 2. 🧭 Escopo Permitido
Você pode modificar:
- [lista de arquivos/diretórios]

## 3. 🚫 Fora de Escopo
NÃO modificar:
- Storage do usuário
- `.ssh/`, `.gnupg/`, `.env` reais
- Boot, rede, GPU, storage, firewall, SSH, secrets
- [outros items específicos da tarefa]

## 4. 📁 Arquivos obrigatórios para leitura
Leia integralmente antes de qualquer modificação:
- `AGENTS.md`
- `.agents/rules/00-core.md`
- [lista completa]

## 5. 📐 Regras Obrigatórias
- O código é a fonte da verdade.
- Toda mudança deve ser pequena e isolada.
- NUNCA inventar comportamento não existente no repo.
- NUNCA usar `git add .`.
- Commits pequenos, temáticos e explícitos.
- Sempre validar antes de declarar pronto.

## 6. 🛠️ Plano de Execução
### Passo A — [Análise]
### Passo B — [Implementação]
### Passo C — [Validação]

## 7. ✅ Comandos de Validação
```sh
cd /etc/kryonix
kryonix fmt
kryonix check --host <host>
kryonix rebuild --host <host>
```

## 8. ⚠️ Riscos
- [lista de riscos concretos]

## 9. 🔄 Rollback
- [procedimentos de reversão]

## 10. 🏁 Critérios de Conclusão
A tarefa está pronta quando:
- [condições verificáveis]
```

---

## Critérios de Saída desta Skill

Um prompt gerado por esta skill está "pronto" quando:
- Define objetivo, escopo e fora de escopo
- Lista arquivos necessários para leitura
- Impõe regras obrigatórias
- Explica riscos com rollback
- Inclui comandos reais do Kryonix
- Proíbe `git add .`
- Garante commits pequenos e temáticos
- Exige validação antes de aplicar
- Contém critérios de conclusão verificáveis

## Riscos

- Gerar prompt genérico sem contexto do Kryonix
- Omitir seções de segurança críticas
- Permitir que o agente alvo opere sem ler o repo
- Inventar commands ou paths que não existem
