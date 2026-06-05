---

## 38. Kryonix Brain: Obsidian, Neo4j, RAG, GraphRAG e CAG

Esta seção endurece o contrato operacional para qualquer agente que trabalhe no **Kryonix Brain**.

### 38.1 Regra principal: Obsidian não é substituído por Neo4j

O **Vault Obsidian** continua sendo a fonte humana de conhecimento. O **Neo4j** é uma base local derivada, reconstruível e consultável por IA.

```txt
Obsidian/Vault = fonte humana editável, notas Markdown, MOCs, playbooks, contexto manual
repo Kryonix    = fonte operacional/declarativa, NixOS, código, módulos, hosts
Neo4j           = grafo derivado, entidades, relações, proveniência, memória e rastros
LightRAG        = recuperação textual/semântica sobre documentos/chunks
CAG/cache       = contexto estável pré-computado para reduzir latência
Ollama          = inferência local
```

Não trate Neo4j como “outro Obsidian”. Não edite conhecimento primário manualmente no Neo4j. O grafo deve ser reconstruível a partir de fontes versionadas e/ou aprovadas.

### 38.2 Fonte de verdade

Precedência para conhecimento do Brain:

1. Código real do repo: `flake.nix`, `hosts/**`, `modules/**`, `profiles/**`, `home/**`, `packages/**`.
2. Documentação canônica em `docs/**`.
3. Contexto de IA em `docs/ai/**`, `.ai/**` e `.agents/**`.
4. Vault Obsidian via CLI aprovada.
5. Neo4j/LightRAG como índice derivado.
6. Memória de conversas e histórico.

Se Neo4j divergir do repo ou do Vault, o Neo4j deve ser considerado desatualizado e reindexado.

### 38.3 Proveniência obrigatória

Todo documento, chunk, entidade e relação criada por ingestão deve carregar proveniência mínima:

```txt
source_path
source_type
source_hash / sha256
repo_commit quando aplicável
created_at / indexed_at
chunk_index
embedding_model
extractor
confidence quando aplicável
```

Sem proveniência, o conteúdo não deve ser usado como grounding confiável.

---

## 39. Layout canônico de estado em `/var/lib/kryonix`

`/var/lib/kryonix` deve guardar **estado gerado por serviços**, não documentação humana primária.

### 39.1 Estrutura alvo

```txt
/var/lib/kryonix/
├── brain/
│   ├── lightrag/
│   │   ├── storage/
│   │   ├── cache/
│   │   └── snapshots/
│   ├── neo4j/
│   │   ├── data/
│   │   ├── logs/
│   │   ├── import/
│   │   └── plugins/
│   ├── rag/
│   │   ├── manifests/
│   │   ├── chunks/
│   │   ├── embeddings/
│   │   ├── rerank/
│   │   └── cache/
│   ├── cag/
│   │   ├── context-cache/
│   │   ├── prompt-cache/
│   │   └── invalidation/
│   ├── reasoning/
│   │   ├── traces/
│   │   └── reports/
│   └── ingest/
│       ├── queue/
│       ├── processed/
│       ├── failed/
│       └── quarantine/
```

Também usar:

```txt
/etc/kryonix/brain.env = secrets/config sensível fora do Git
/var/log/kryonix       = logs persistentes
/run/kryonix           = sockets, PID e runtime temporário
/etc/kryonix           = checkout/deployment do repo, quando esse for o padrão real do host
```

### 39.2 Regras para migração de estado

- Não apagar diretórios antigos automaticamente.
- Não mover dados sem backup.
- Criar diretórios via `systemd.tmpfiles.rules` quando possível.
- Declarar ownership e permissões explicitamente.
- Documentar plano de migração em `docs/brain/STATE_LAYOUT.md`.
- Se symlink temporário for necessário, documentar data e critério de remoção.

---

## 40. Neo4j local no Kryonix

Neo4j deve ser local ao `glacier` por padrão e não exposto publicamente.

### 40.1 Uso correto

Neo4j deve armazenar:

```txt
Document, Chunk, Entity, Host, Service, File, NixModule, NixOption,
Command, Port, Model, GPU, Issue, Decision, ReasoningTrace,
ReasoningStep, ToolCall, ToolResult, Evidence
```

Relações recomendadas:

```txt
(Document)-[:HAS_CHUNK]->(Chunk)
(Chunk)-[:MENTIONS]->(Entity)
(File)-[:IMPORTS]->(File)
(File)-[:DECLARES]->(Service)
(File)-[:DEFINES_OPTION]->(NixOption)
(Host)-[:IMPORTS]->(NixModule)
(Host)-[:RUNS]->(Service)
(Service)-[:LISTENS_ON]->(Port)
(Service)-[:DEPENDS_ON]->(Service)
(Command)-[:VALIDATES]->(Service)
(Message)-[:TRIGGERED]->(ReasoningTrace)
(ReasoningTrace)-[:HAS_STEP]->(ReasoningStep)
(ReasoningStep)-[:USED_TOOL]->(ToolCall)
(ToolCall)-[:RETURNED]->(ToolResult)
(Decision)-[:BASED_ON]->(Evidence)
```

### 40.2 Segurança de Neo4j

- Bolt/HTTP devem ficar restritos a localhost, LAN controlada ou Tailscale.
- Não abrir `7474` ou `7687` globalmente sem justificativa.
- Usar credenciais fora do Git e fora do Nix store.
- Text2Cypher gerado por LLM deve ser read-only por padrão.
- Bloquear ou validar: `DELETE`, `DETACH DELETE`, `CREATE`, `MERGE`, `SET`, `DROP`, `LOAD CSV`, `CALL dbms.*`, `CALL apoc.*`.
- Toda query gerada por LLM precisa de `LIMIT`, timeout e log de auditoria.

---

## 41. RAG modular, GraphRAG e CAG

O Kryonix Brain não deve depender de RAG naïve como arquitetura final.

### 41.1 Pipeline RAG mínimo endurecido

```txt
1. Query normalization
2. Query routing
3. Hybrid retrieval
   - vector search
   - full-text/BM25
   - graph traversal
4. Metadata filtering
5. Reranking
6. Context compression
7. Prompt assembly
8. LLM answer
9. Citation/provenance
10. Feedback/reasoning trace
```

### 41.2 Quando usar cada técnica

```txt
Vector RAG  = achar significado aproximado
Full-text   = nomes exatos, paths, opções Nix, comandos
GraphRAG    = relações, dependências, causalidade, multi-hop
Text2Cypher = perguntas estruturais com schema limitado/read-only
CAG/cache   = contexto estável e frequente
```

### 41.3 CAG/cache

CAG/cache não substitui RAG. Use para contexto estável:

```txt
arquitetura do projeto
mapa de hosts
serviços conhecidos
comandos de validação
políticas de segurança
estrutura do flake
índice de módulos NixOS
```

Chave de cache deve considerar:

```txt
normalized_query
retrieval_profile
model_name
embedding_model
index_version
repo_commit
vault_snapshot_hash
top_k
schema_version
chunking_version
```

Invalidar cache quando mudar:

```txt
git commit
flake.lock
arquivos indexados
hash do vault
modelo de embedding
schema Neo4j
config de chunking
perfil de retrieval
```

---

## 42. Ingestão real do projeto inteiro

O Brain deve aprender/indexar o projeto inteiro como conhecimento consultável, incluindo arquivos `.nix`.

### 42.1 Comandos alvo

```bash
kryonix brain ingest repo --path /etc/kryonix
kryonix brain ingest vault
kryonix brain ingest all
kryonix brain graph stats
kryonix brain graph query --read-only '<cypher>'
```

Se esses comandos ainda não existirem, documente como roadmap/stub. Não finja execução.

### 42.2 Arquivos incluídos

Indexar no mínimo:

```txt
.nix
.md
.py
.rs
.toml
.json
.yaml
.yml
.sh
.service
.conf
.env.example
```

### 42.3 Exclusões obrigatórias

Nunca indexar:

```txt
.git/
result
result-*
.direnv/
node_modules/
target/
__pycache__/
*.pyc
*.png
*.jpg
*.jpeg
*.webp
*.mp4
*.iso
*.qcow2
.env
brain.env
id_ed25519*
*.key
*.pem
*.secret
```

### 42.4 Chunking para `.nix`

Arquivos `.nix` devem ser divididos por estrutura, não só por tamanho:

```txt
cabeçalho/comentários de módulo
imports
options / mkOption
config / mkIf
systemd.services
services.*
environment.systemPackages
networking.*
firewall
hardware
attrsets grandes
```

Extrair entidades técnicas:

```txt
Host
Service
NixModule
NixOption
Package
File
Command
Port
Model
GPU
VaultNote
Doc
Issue
Decision
```

### 42.5 Ingestão incremental

- Calcular `sha256` por arquivo.
- Calcular hash por chunk.
- Não reindexar arquivo sem mudança.
- Marcar chunks removidos como obsoletos antes de apagar.
- Manter manifesto em `/var/lib/kryonix/brain/rag/manifests`.

---

## 43. Organização de raiz, `skills/` e documentação

A raiz do repo deve ficar compreensível. Pastas soltas devem ser auditadas e movidas com cuidado.

### 43.1 Antes de mover

```bash
find . -maxdepth 2 -type d | sort
git ls-files
rg "skills|caminho-antigo|nome-da-pasta" .
```

### 43.2 Regras de destino

```txt
documentação       -> docs/
prompt/agente      -> .agents/ ou .ai/
skill documental   -> docs/skills/ ou docs/ai/skills/ conforme uso real
script executável  -> scripts/ ou packages/
asset              -> files/
módulo Nix         -> modules/
contexto histórico -> context/
```

Use `git mv` para preservar histórico. Atualize referências. Não quebrar ferramentas que esperam `skills/**`; se necessário, criar symlink temporário ou compat layer documentada.

---

## 44. Validação obrigatória para mudanças Brain/RAG/Neo4j

Validação documental:

```bash
rg -n "Neo4j|GraphRAG|CAG|RAG|Obsidian|/var/lib/kryonix" docs .ai .agents AGENTS.md || true
```

Validação Nix:

```bash
nix fmt . || true
nix flake check --keep-going
nh os build .#glacier -L --show-trace
```

Validação Brain, se runtime disponível:

```bash
kryonix brain health
kryonix brain stats
kryonix brain search "Como funciona o pipeline RAG do Kryonix?"
systemctl status ollama --no-pager
systemctl status kryonix-lightrag --no-pager
systemctl status kryonix-brain-api --no-pager
```

Validação Neo4j, se habilitado:

```bash
systemctl status neo4j --no-pager
cypher-shell "RETURN 1 AS ok;"
cypher-shell "CALL db.schema.visualization();"
```

Se algum comando não existir, registre como pendência/roadmap.
