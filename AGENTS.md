# KRYONIX AGENTS

## 🧠 Visão Geral

Kryonix é uma plataforma baseada em NixOS orientada a:

- Configuração declarativa (NixOS)
- GitOps como fonte única de verdade
- Memória local estruturada (RAG)
- Execução via CLI inteligente

Objetivo:

> Minimizar dependência de contexto externo e maximizar previsibilidade, rastreabilidade e eficiência operacional.

---

## ⚙️ Princípios Fundamentais

1. **Fonte de verdade = Git (`/etc/kryonix`)**
2. **Estado do sistema é sempre declarativo**
3. **Contexto local precede qualquer fonte externa**
4. **Sem duplicação de conhecimento**
5. **Toda ação relevante gera persistência de contexto**
6. **Operações devem ser reproduzíveis e auditáveis**

---

## 🧭 Modelo de Execução do Agente

Antes de qualquer ação:

1. Identificar objetivo da tarefa
2. Determinar impacto no sistema (host, serviço, estado)
3. Consultar contexto local obrigatório
4. Validar consistência com estado atual
5. Escolher menor ação segura possível

Durante execução:

- Preferir operações determinísticas
- Evitar efeitos colaterais não documentados
- Validar cada etapa crítica

Após execução:

- Atualizar estado (`CURRENT_STATE.md`)
- Registrar decisão (se aplicável)
- Persistir aprendizado relevante

---

## 📚 Ordem de Consulta (OBRIGATÓRIA)

Sempre seguir esta prioridade:

1. `AGENTS.md`
2. `context/INDEX.md`
3. `context/`
4. `skills/`
5. Código do repositório
6. Web (**último recurso**)

Se a resposta existir localmente, **não usar internet**.

---

## 🧠 Estrutura de Memória

### 📂 `context/` (Memória persistente)

Fonte primária de contexto operacional.

Arquivos principais:

- `CURRENT_STATE.md` → estado real do sistema
- `ARCHITECTURE.md` → visão estrutural
- `INDEX.md` → índice navegável
- `RUNBOOKS/` → procedimentos operacionais
- `DECISIONS/` → decisões técnicas (ADR-like)
- `INCIDENTS/` → falhas e resoluções
- `HOSTS/` → estado e configuração por host

---

### 🧩 `skills/` (Conhecimento reutilizável)

Cada skill deve conter:

- checklist operacional
- exemplos reais
- solução padrão
- edge cases conhecidos
- limitações

Uso:

> Sempre preferir skill existente ao reinventar solução.

---

### 🧾 `prompts/`

Automação estruturada de tarefas com IA.

- tarefas repetitivas
- geração controlada
- workflows previsíveis

---

## 🧠 Regras do Agente

### ✔ Sempre

- Consultar contexto local antes de agir
- Validar contra `CURRENT_STATE.md`
- Atualizar estado após mudanças relevantes
- Registrar decisões em `DECISIONS/`
- Classificar corretamente:
  - incidente novo
  - incidente recorrente
- Preferir soluções:
  - declarativas
  - idempotentes
  - reproduzíveis

---

### ❌ Nunca

- Usar web sem esgotar contexto local
- Duplicar informação já existente
- Alterar estado sem registrar
- Ignorar inconsistências de estado
- Criar solução “one-off” sem documentação
- Introduzir lógica imperativa quando declarativa é possível

---

## 🔄 Gestão de Estado

### Regra central:

> O estado real deve sempre convergir para o estado declarativo.

Se divergência for detectada:

1. Identificar origem do drift
2. Corrigir via configuração declarativa
3. Nunca corrigir apenas manualmente sem persistir

---

## ⚙️ Operações Principais

### 🔄 Sync (GitOps)

```bash
kryonix sync