# Kryonix — Contexto e Memória Canônica Completa

> Arquivo recomendado:
>
> ```txt
> .ai/KRYONIX_CONTEXT_MEMORY_FULL.md
> ```
>
> Objetivo: servir como memória operacional longa do projeto Kryonix, contexto obrigatório para agentes de IA, documentação interna e decisões futuras.  
> Este arquivo deve ser tratado como fonte principal de continuidade entre sessões.

---

# 1. Identidade do Projeto

## 1.1 Nome

O projeto se chama **Kryonix**.

Kryonix não deve ser tratado apenas como dotfiles, rice, scripts ou configuração pessoal.  
Kryonix é uma plataforma NixOS declarativa, inteligente, auditável e progressivamente autônoma.

## 1.2 Visão

Transformar o ambiente pessoal do usuário em um sistema operacional inteligente baseado em:

- NixOS Flakes;
- CLI própria `kryonix`;
- automação declarativa;
- IA local;
- RAG;
- CAG/context cache;
- GraphRAG;
- Neo4j;
- Ollama;
- LightRAG;
- Obsidian/Vault;
- segurança operacional;
- infraestrutura local;
- acesso remoto seguro;
- memória persistente de agentes;
- auditoria e explicabilidade.

O Kryonix deve evoluir para um sistema capaz de:

- diagnosticar a si mesmo;
- saber em qual host está rodando;
- operar como client ou server;
- consultar Brain remoto;
- validar serviços;
- organizar conhecimento;
- registrar decisões;
- recuperar contexto antigo;
- sugerir correções;
- aplicar mudanças de forma controlada;
- nunca expor segredos;
- nunca executar ação destrutiva sem intenção explícita;
- priorizar NixOS declarativo em vez de gambiarra temporária.

---

# 2. Regra de Ouro: Usar `kryonix` Para Tudo

## 2.1 Princípio

Sempre que existir um comando `kryonix` equivalente, ele deve ser preferido no lugar do comando cru do NixOS, Home Manager, Git ou serviços.

O objetivo é fazer a CLI `kryonix` virar a interface operacional canônica do sistema.

## 2.2 Por quê?

Porque a CLI `kryonix` pode incorporar:

- detecção automática do host;
- papel do host: client/server;
- flake root correto;
- logs melhores;
- validação antes/depois;
- proteção contra ações perigosas;
- modo remoto para Glacier;
- checagem de secrets;
- checagem de estado Git;
- integração com Brain;
- integração com GraphRAG;
- comandos padronizados para o usuário.

## 2.3 Regra prática

Evitar sugerir diretamente:

```bash
sudo nixos-rebuild switch --flake .#glacier
sudo nixos-rebuild switch --flake .#inspiron
nh os switch
home-manager switch
nix flake check
nix build .#kryonix
git pull --rebase
git status
systemctl status ...
```

Preferir quando possível:

```bash
kryonix switch
kryonix switch glacier
kryonix switch inspiron
kryonix home
kryonix check
kryonix rebuild
kryonix pull
kryonix git-status
kryonix doctor
kryonix services status
```

Quando o comando `kryonix` ainda não existir ou não cobrir o caso, o comando cru pode ser usado, mas deve ser encarado como candidato a virar subcomando futuro.

---

# 3. Tabela de Substituição de Comandos

## 3.1 NixOS

| Comando bruto | Preferir |
|---|---|
| `sudo nixos-rebuild switch --flake .#HOST` | `kryonix switch HOST` |
| `sudo nixos-rebuild test --flake .#HOST` | `kryonix test HOST` ou `kryonix test` |
| `nix build .#nixosConfigurations.HOST.config.system.build.toplevel` | `kryonix rebuild HOST` |
| `nix flake check --keep-going` | `kryonix check` |
| `nix fmt .` | `kryonix fmt` |
| `nix repl` | `kryonix repl` |
| `nh clean all` | `kryonix clean` |
| `nix flake update` | `kryonix update` |
| `nix build .#kryonix --no-link` | `kryonix build` ou `nix build .#kryonix --no-link` enquanto não existir |

## 3.2 Home Manager

| Comando bruto | Preferir |
|---|---|
| `home-manager switch --flake .#USER@HOST` | `kryonix home` |
| `nh home switch .#USER@HOST` | `kryonix home` |

## 3.3 Git

| Comando bruto | Preferir |
|---|---|
| `git status --short` | `kryonix git-status` |
| `git pull --rebase` | `kryonix pull` |
| `git fetch && git pull` | `kryonix pull` |
| fluxo completo pull + validação + deploy | `kryonix sync` |

Comandos Git brutos ainda são aceitáveis para revisão fina:

```bash
git diff
git diff --stat
git log --oneline --decorate -5
git grep
git ls-files
```

Mas a operação comum do sistema deve migrar para `kryonix`.

## 3.4 Brain

| Objetivo | Preferir |
|---|---|
| health do Brain | `kryonix brain health` |
| health local | `kryonix brain health --local` |
| stats | `kryonix brain stats` |
| busca | `kryonix brain search "pergunta"` |
| pergunta RAG | `kryonix brain ask "pergunta"` |
| remote config | `kryonix brain remote configure` |
| status do túnel Brain | `kryonix brain remote status` |
| API key | `kryonix brain api-key status` / `generate` |

## 3.5 GraphRAG / Neo4j

| Objetivo | Preferir |
|---|---|
| status do grafo | `kryonix graph status` |
| schema | `kryonix graph schema` |
| ingestão simulada | `kryonix graph ingest --dry-run` |
| query read-only | `kryonix graph query --cypher "MATCH ... LIMIT 10"` |
| doctor do grafo | `kryonix graph doctor` |
| exemplos | `kryonix graph examples` |
| top entidades | `kryonix graph top` |

## 3.6 Acesso remoto

| Objetivo | Preferir |
|---|---|
| status VNC | `kryonix remote vnc status` |
| iniciar VNC/tunnel | `kryonix remote vnc start` |
| parar VNC/tunnel | `kryonix remote vnc stop` |

## 3.7 Serviços

| Objetivo | Preferir |
|---|---|
| diagnóstico geral | `kryonix doctor` |
| status de serviços | `kryonix services status` se existir |
| Ollama | `kryonix ollama status/start/stop/run/pull` |
| MCP | `kryonix mcp check` |
| Vault | `kryonix vault scan/index` |

Quando a CLI ainda não tiver subcomando, usar `systemctl`, mas registrar como melhoria futura.

---

# 4. Hosts Canônicos

## 4.1 Inspiron

O Inspiron é:

```txt
workstation principal
dev machine
cliente remoto
interface de operação
máquina onde o usuário interage mais
```

Responsabilidades:

- desenvolvimento;
- edição do repo;
- interface gráfica principal;
- controle do Glacier;
- acesso remoto via túnel;
- consulta ao Brain remoto;
- não duplicar índice pesado;
- não rodar RAG local por padrão.

Papel esperado:

```bash
KRYONIX_ROLE=client
KRYONIX_BRAIN_MODE=remote
```

Regra:

```txt
Inspiron não deve fazer fallback local silencioso para RAG pesado.
```

Se o usuário quiser RAG local, precisa ser explícito:

```bash
export KRYONIX_LOCAL_RAG_ENABLE=true
```

## 4.2 Glacier

O Glacier é:

```txt
servidor local de IA
servidor Brain
servidor RAG
servidor LightRAG
servidor Ollama
servidor Neo4j
servidor WayVNC local-only
fonte canônica de runtime pesado
```

Responsabilidades:

- Ollama;
- modelos locais;
- Brain API;
- LightRAG;
- Neo4j;
- GraphRAG;
- Vault canônico;
- armazenamento pesado;
- acesso remoto seguro;
- serviços de IA e memória.

Papel esperado:

```bash
KRYONIX_ROLE=server
```

---

# 5. Storage Canônico

## 5.1 Raiz lógica

No Glacier:

```txt
/var/lib/kryonix
```

## 5.2 Backend físico

```txt
/home/storage/kryonix
```

## 5.3 Symlink esperado

```txt
/var/lib/kryonix -> /home/storage/kryonix
```

## 5.4 Motivo

A partição `/` já esteve pressionada por uso de storage pesado.  
Dados grandes devem ir para `/home/storage`.

## 5.5 Brain/LightRAG

Storage correto:

```txt
/var/lib/kryonix/brain/storage
```

Proibido como default:

```txt
/var/lib/kryonix/storage
```

Se qualquer comando mostrar:

```txt
working_dir: /var/lib/kryonix/storage
```

isso é erro de configuração.

## 5.6 Ollama

Modelos devem ficar em:

```txt
/home/storage/ollama/models
```

Não baixar modelos grandes em `/var/lib/ollama/models` se isso cair na partição `/`.

## 5.7 Neo4j

Caminho lógico:

```txt
/var/lib/kryonix/brain/neo4j
```

Subdiretórios:

```txt
/var/lib/kryonix/brain/neo4j/data
/var/lib/kryonix/brain/neo4j/logs
/var/lib/kryonix/brain/neo4j/import
/var/lib/kryonix/brain/neo4j/plugins
/var/lib/kryonix/brain/neo4j/conf
```

Ownership esperado:

```txt
neo4j:neo4j
```

---

# 6. Serviços Principais

## 6.1 Glacier

Serviços esperados:

```txt
ollama.service
kryonix-lightrag.service
kryonix-brain-api.service
neo4j.service
tailscaled.service
sshd.service
kryonix-wayvnc user service
```

Validação preferida:

```bash
kryonix doctor
kryonix brain health --local
kryonix graph doctor
kryonix remote vnc status
```

Validação bruta permitida quando necessário:

```bash
systemctl status ollama --no-pager -l
systemctl status kryonix-lightrag --no-pager -l
systemctl status kryonix-brain-api --no-pager -l
systemctl status neo4j --no-pager -l
systemctl --user status kryonix-wayvnc --no-pager -l
```

## 6.2 Inspiron

Serviços/fluxos esperados:

```txt
kryonix-brain-tunnel user service
kryonix-glacier-vnc-tunnel user service
ssh-agent
tailscaled
```

Validação preferida:

```bash
kryonix brain remote status
kryonix remote vnc status
kryonix doctor
```

---

# 7. Brain API

## 7.1 Contrato HTTP

A Brain API roda no Glacier.

Contrato:

```txt
GET  /health = público
GET  /stats  = protegido por X-API-Key
POST /search = protegido por X-API-Key
```

## 7.2 Bind seguro

A Brain API deve escutar por padrão em:

```txt
127.0.0.1:8000
```

Proibido por padrão:

```txt
0.0.0.0:8000
:::8000
*:8000
```

## 7.3 Acesso remoto correto

Do Inspiron, usar túnel:

```txt
Inspiron 127.0.0.1:18000
  -> SSH/Tailscale tunnel
  -> Glacier 127.0.0.1:8000
```

Variáveis no client:

```bash
export KRYONIX_ROLE=client
export KRYONIX_BRAIN_MODE=remote
export KRYONIX_REMOTE_BRAIN_URL=http://127.0.0.1:18000
```

## 7.4 API key

Arquivo local no Glacier:

```txt
/etc/kryonix/brain.env
```

Permissão:

```txt
root:root 0600
```

Formato:

```txt
KRYONIX_BRAIN_API_KEY=<valor>
```

Nunca commitar.

Nunca imprimir.

Nunca colocar no Nix store.

## 7.5 Validação segura

Sem imprimir a chave:

```bash
K="$(sudo sed -n 's/^KRYONIX_BRAIN_API_KEY=//p' /etc/kryonix/brain.env)"
curl -fsS -H "X-API-Key: $K" http://127.0.0.1:8000/stats | jq .
unset K
```

Resultado esperado atual:

```txt
entities: 4391
relations: 5381
docs: 152
consistency_status: OK
working_dir: /var/lib/kryonix/brain/storage
```

---

# 8. Neo4j / GraphRAG

## 8.1 Estado esperado

Neo4j roda no Glacier.

Portas:

```txt
HTTP 127.0.0.1:7474
Bolt 127.0.0.1:7687
```

Proibido:

```txt
0.0.0.0:7474
0.0.0.0:7687
:::7474
:::7687
```

## 8.2 Secret

Arquivo:

```txt
/etc/kryonix/neo4j.env
```

Permissão:

```txt
root:root 0600
```

Formato:

```txt
NEO4J_AUTH=neo4j/<senha>
```

Nunca imprimir.

Nunca commitar.

## 8.3 Princípio de GraphRAG

Embeddings respondem:

```txt
o que parece com isso?
```

Grafos respondem:

```txt
como isso se conecta e por quê?
```

O Kryonix deve combinar:

```txt
Vector RAG
Full-text search
Graph traversal
Text2Cypher seguro
Reasoning memory
Context grounding
```

## 8.4 Schema V1 esperado

Nós:

```txt
Host
Service
File
Command
Issue
Port
Model
GPU
Document
Chunk
Entity
ReasoningTrace
ReasoningStep
ToolCall
ToolResult
```

Relações:

```txt
(Host)-[:RUNS]->(Service)
(Service)-[:DEPENDS_ON]->(Service)
(Service)-[:LISTENS_ON]->(Port)
(File)-[:DECLARES]->(Service)
(File)-[:IMPORTS]->(File)
(Command)-[:VALIDATES]->(Service)
(Command)-[:REPAIRS]->(Issue)
(Issue)-[:AFFECTS]->(Host)
(Issue)-[:AFFECTS]->(Service)
(Model)-[:SERVED_BY]->(Service)
(Host)-[:HAS_GPU]->(GPU)
(Service)-[:USES]->(Model)
(Document)-[:HAS_CHUNK]->(Chunk)
(Chunk)-[:HAS_ENTITY]->(Entity)
(Entity)-[:MENTIONED_IN]->(Chunk)
(ReasoningTrace)-[:HAS_STEP]->(ReasoningStep)
(ReasoningStep)-[:USED_TOOL]->(ToolCall)
(ToolCall)-[:RETURNED]->(ToolResult)
```

## 8.5 Segurança Text2Cypher

Proibido para queries geradas por LLM:

```txt
CREATE
MERGE
DELETE
DETACH DELETE
SET
REMOVE
CALL dbms.*
CALL apoc.*
LOAD CSV
```

Permitido inicialmente:

```txt
MATCH
OPTIONAL MATCH
WHERE
RETURN
WITH
ORDER BY
LIMIT
```

Obrigatório:

```txt
LIMIT
timeout
usuário read-only
logs de auditoria
```

---

# 9. WayVNC / Acesso Remoto Gráfico

## 9.1 Arquitetura segura

```txt
Inspiron localhost:5901
        ↓
SSH tunnel / Tailscale
        ↓
Glacier 127.0.0.1:5900
        ↓
WayVNC
        ↓
Hyprland/Wayland session
```

Viewer:

```txt
127.0.0.1:5901
```

## 9.2 Proibido

```txt
Não abrir 5900 na WAN.
Não bindar WayVNC em 0.0.0.0.
Não liberar 5900/tcp publicamente.
Não commitar senha VNC.
Não remover passphrase das chaves SSH.
```

## 9.3 Comando preferido

```bash
kryonix remote vnc status
kryonix remote vnc start
kryonix remote vnc stop
```

## 9.4 Validação

```bash
kryonix remote vnc status
```

Estado esperado:

```txt
Inspiron Tunnel : ATIVO (escutando em 127.0.0.1:5901)
Glacier WayVNC  : ATIVO (escutando em 127.0.0.1:5900)
```

---

# 10. CLI Inteligente

## 10.1 Objetivo

A CLI `kryonix` deve evoluir de wrapper para operador inteligente.

Ela deve:

- entender o host atual;
- detectar role client/server;
- saber se está no Inspiron ou Glacier;
- saber se o repo está dirty;
- validar secrets;
- validar serviços;
- validar portas;
- sugerir próximos passos;
- consultar o Brain;
- consultar GraphRAG;
- explicar riscos;
- rodar em dry-run por padrão para ações perigosas;
- nunca executar mutação sem intenção explícita.

## 10.2 Comandos futuros desejados

```bash
kryonix smart status
kryonix smart next
kryonix smart diagnose brain
kryonix smart diagnose remote
kryonix smart diagnose graph
kryonix smart diagnose secrets
kryonix smart ask "por que o Brain não conecta no Ollama?"
kryonix smart plan "habilitar túnel VNC seguro"
kryonix smart fix brain-api --dry-run
```

## 10.3 Filosofia

```txt
observar -> explicar -> sugerir -> dry-run -> aplicar -> validar -> auditar
```

Nunca inverter essa ordem.

## 10.4 Ações perigosas

A CLI inteligente nunca deve fazer automaticamente:

```txt
switch
reboot
delete
repair destrutivo
reindexação pesada
limpeza de storage
reset de git
force push
exposição de porta
alteração de segredo
```

Sem intenção explícita do usuário.

---

# 11. Git e Fluxo de Trabalho

## 11.1 Fluxo canônico

No Inspiron:

```bash
cd /etc/kryonix
kryonix git-status
git diff --stat
kryonix check
kryonix rebuild
git add <arquivos certos>
git commit -m "<mensagem clara>"
git push origin main
```

No Glacier:

```bash
ssh glacier-public
cd /etc/kryonix
git pull --ff-only origin main
kryonix rebuild
kryonix test
```

## 11.2 Commits pequenos

Nunca misturar assuntos:

```txt
Brain remoto/local
MCP
Codex
Neo4j
WayVNC
docs
home-manager fix
CLI smart
GraphRAG
```

Cada tema deve virar commit separado.

## 11.3 Tags

Checkpoint atual desejado:

```txt
v0.3.3 secure remote access baseline
```

Tags devem ser usadas para marcos reais, depois de validação.

---

# 12. Segredos e Segurança

## 12.1 Nunca commitar

```txt
brain.env
neo4j.env
.env
.env.local
.env.*
tokens
secrets
private keys
id_ed25519
.mcp.json se contiver credenciais
```

## 12.2 `.gitignore` esperado

```gitignore
# Kryonix local secrets - never commit
/brain.env
/neo4j.env
/.env
*.secret
*.token
id_ed25519
id_ed25519.*
```

## 12.3 Scan antes de commit

```bash
git diff | rg -n "api[_-]?key|token|secret|password|passwd|bearer|authorization|private|id_ed25519|KRYONIX_BRAIN_API_KEY|NEO4J_AUTH|BEGIN .*PRIVATE" -i || true

git ls-files | rg '(^|/)(brain\.env|neo4j\.env|\.env|id_ed25519|.*secret.*|.*token.*)$' || true

git grep -n "KRYONIX_BRAIN_API_KEY=.*[a-fA-F0-9]\{32,\}" || true
git grep -n "NEO4J_AUTH=neo4j/" || true
```

## 12.4 Rotação

Qualquer segredo exibido em chat, commit, log ou walkthrough deve ser considerado vazado.

Rotacionar Brain API key:

```bash
NEW_KEY="$(python3 - <<'PY'
import secrets
print(secrets.token_hex(32))
PY
)"
```

Rotacionar Neo4j password:

```bash
NEW_PASS="$(python3 - <<'PY'
import secrets
print(secrets.token_urlsafe(32))
PY
)"
```

Nunca sobrescrever env se a variável gerada estiver vazia.

---

# 13. Validações Padrão

## 13.1 Validação local

```bash
cd /etc/kryonix

kryonix git-status
kryonix fmt
git diff --check
kryonix check
kryonix rebuild

kryonix brain health
kryonix brain health --local
kryonix remote vnc status
```

## 13.2 Validação bruta quando necessário

```bash
nix fmt . || true
git diff --check
nix flake check --keep-going
nix build .#kryonix --no-link
```

## 13.3 Validação Glacier

```bash
ssh glacier-public '
cd /etc/kryonix
kryonix git-status
kryonix brain health --local
kryonix graph doctor
kryonix remote vnc status
'
```

## 13.4 Portas sensíveis

Verificar:

```bash
ss -ltnp | rg "5900|5901|7474|7687|8000|18000"
```

Permitido:

```txt
127.0.0.1:5900
127.0.0.1:5901
127.0.0.1:7474
127.0.0.1:7687
127.0.0.1:8000
127.0.0.1:18000
[::1]:5901
[::1]:18000
```

Proibido para serviços sensíveis:

```txt
0.0.0.0:5900
0.0.0.0:5901
0.0.0.0:7474
0.0.0.0:7687
0.0.0.0:8000
:::5900
:::5901
:::7474
:::7687
:::8000
```

---

# 14. Estado Atual Consolidado

## 14.1 Brain

Estado esperado:

```txt
Brain remoto no Inspiron: OK
Brain local no Inspiron: LOCAL_DISABLED
Brain local no Glacier: OK
Storage: /var/lib/kryonix/brain/storage
```

Métricas atuais esperadas:

```txt
entities: 4391
relations: 5381
docs: 152
consistency_status: OK
```

## 14.2 Neo4j

Estado esperado:

```txt
neo4j.service active
7474 local-only
7687 local-only
doctor OK
```

## 14.3 WayVNC

Estado esperado:

```txt
Glacier WayVNC: 127.0.0.1:5900
Inspiron tunnel: 127.0.0.1:5901
```

## 14.4 Brain tunnel

Estado esperado:

```txt
Inspiron tunnel: 127.0.0.1:18000
Glacier Brain API: 127.0.0.1:8000
```

## 14.5 CLI

A CLI foi modularizada em:

```txt
packages/kryonix-cli/
├── brain.sh
├── core.sh
├── git.sh
├── main.sh
├── nixos.sh
├── remote.sh
└── services.sh
```

Motivo: arquivo monolítico com milhares de linhas estava gerando erros de indentação, heredoc e manutenção difícil.

A modularização é correta se:

```txt
bash -n packages/kryonix-cli/*.sh
nix build .#kryonix --no-link
nix run .#kryonix -- --help
nix run .#kryonix -- brain health
nix run .#kryonix -- remote vnc status
```

passarem.

---

# 15. Próximas Fases Recomendadas

## 15.1 Fase A — Checkpoint seguro

- validar estado;
- commit limpo;
- tag;
- documentação atualizada.

## 15.2 Fase B — CLI inteligente

Implementar:

```bash
kryonix smart status
kryonix smart next
kryonix smart diagnose brain
kryonix smart diagnose remote
kryonix smart diagnose graph
kryonix smart diagnose secrets
```

## 15.3 Fase C — GraphRAG controlado

Implementar ou reforçar:

```bash
kryonix graph schema
kryonix graph ingest --dry-run
kryonix graph query --cypher "MATCH ... LIMIT 10"
kryonix graph doctor
```

Sem ingestão destrutiva por padrão.

## 15.4 Fase D — Neo4j read-only user

Criar usuário read-only para queries LLM/Text2Cypher.

## 15.5 Fase E — Reasoning Memory

Registrar rastros:

```txt
ReasoningTrace
ReasoningStep
ToolCall
ToolResult
```

## 15.6 Fase F — MCP remoto completo

Inspiron como cliente MCP, Glacier como servidor MCP Brain.

## 15.7 Fase G — Vault vivo

- ingestão controlada;
- curadoria;
- notas obsoletas;
- sugestões;
- nunca apagar sem revisão.

## 15.8 Fase H — Home inteligente

Sistema para organizar arquivos da home:

- ignorar pastas ocultas;
- analisar downloads/documentos/mídias;
- renomear conforme padrão;
- deduplicar com hash;
- sugerir antes de apagar;
- registrar decisões no Brain;
- usar Rust para core seguro;
- usar Python/LLM para classificação quando necessário.

---

# 16. Regras do Agente

Qualquer agente que trabalhar no Kryonix deve:

1. Ler este arquivo antes de alterar qualquer coisa.
2. Ler `.ai/PROJECT_MEMORY_CURRENT.md`.
3. Ler `README.md`.
4. Ler `flake.nix`.
5. Verificar `git status`.
6. Não misturar assuntos.
7. Não commitar secrets.
8. Não usar comando cru se existir equivalente `kryonix`.
9. Não rodar switch antes de build/test.
10. Não rodar update sem pedido explícito.
11. Não alterar `flake.lock` sem explicar.
12. Não expor portas sensíveis.
13. Não imprimir segredos.
14. Sempre validar depois.
15. Sempre explicar arquivos alterados.
16. Sempre sugerir rollback quando houver risco.

---

# 17. Prompt Curto Para Novos Chats

Use este resumo:

```txt
Estou no projeto Kryonix em /etc/kryonix. Responda sempre em português técnico e prático. Kryonix é minha plataforma NixOS declarativa e inteligente. Use a CLI kryonix como interface principal para tudo; substitua comandos padrão do NixOS/Home Manager/Git por kryonix quando existir equivalente. Hosts: Inspiron = workstation/client remoto; Glacier = servidor IA/RAG/Ollama/LightRAG/Brain API/Neo4j/WayVNC. Storage canônico no Glacier: /var/lib/kryonix -> /home/storage/kryonix. Brain ativo: /var/lib/kryonix/brain/storage com 4391 entidades, 5381 relações, 152 docs. Não usar /var/lib/kryonix/storage. Brain API deve escutar em 127.0.0.1:8000 e ser acessada remotamente por túnel 127.0.0.1:18000. Neo4j local-only em 127.0.0.1:7474 e 127.0.0.1:7687. WayVNC local-only em Glacier 127.0.0.1:5900 e tunnel no Inspiron 127.0.0.1:5901. Nunca commitar brain.env, neo4j.env, .env, tokens ou private keys. Próximas prioridades: checkpoint seguro, CLI inteligente kryonix smart, GraphRAG controlado, Neo4j read-only user, reasoning memory e MCP remoto.
```

---

# 18. Comandos Preferidos de Operação Diária

## 18.1 Status

```bash
kryonix git-status
kryonix doctor
kryonix smart status
```

## 18.2 Atualizar repo

```bash
kryonix pull
```

## 18.3 Validar

```bash
kryonix fmt
kryonix check
kryonix rebuild
```

## 18.4 Aplicar sistema

```bash
kryonix switch
```

## 18.5 Aplicar Home Manager

```bash
kryonix home
```

## 18.6 Brain

```bash
kryonix brain health
kryonix brain stats
kryonix brain search "pergunta"
```

## 18.7 Graph

```bash
kryonix graph status
kryonix graph schema
kryonix graph ingest --dry-run
kryonix graph doctor
```

## 18.8 Remoto

```bash
kryonix remote vnc status
kryonix remote vnc start
```

## 18.9 Deploy seguro

```bash
kryonix sync
```

Mas `kryonix sync` só deve ser usado quando:

```txt
git status está entendido
não há secrets
build/check passaram
o usuário sabe que haverá aplicação/deploy
```

---

# 19. Filosofia Técnica

## 19.1 Declarativo primeiro

Se algo precisa persistir, deve virar NixOS/Home Manager.

## 19.2 Script só como ponte

Scripts são aceitáveis quando:

- validam algo;
- encapsulam lógica operacional;
- serão depois transformados em módulo declarativo.

## 19.3 IA não deve agir sem freio

IA deve:

```txt
entender
explicar
sugerir
gerar plano
validar
pedir confirmação para mutação
```

Antes de executar.

## 19.4 O sistema precisa aprender

Toda correção importante deve gerar:

- doc;
- comando de validação;
- possível entrada no GraphRAG;
- referência futura para o Brain.

---

# 20. Lembretes Críticos

- Use `kryonix` sempre que possível.
- Não use `/var/lib/kryonix/storage`.
- Não exponha Brain API.
- Não exponha Neo4j.
- Não exponha VNC.
- Não commite secrets.
- Não faça fallback local pesado no Inspiron.
- Não misture commits.
- Não rode update sem pedido.
- Não declare fase concluída sem validação.
- Não deixe agente alterar tudo sem diff revisado.
- Prefira `dry-run`.
- Prefira `test` antes de `switch`.
- Prefira GraphRAG read-only antes de ingestão real.
- O Kryonix deve ser auditável, explicável e seguro.
