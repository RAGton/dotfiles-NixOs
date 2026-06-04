# Estudo de Aposentadoria da Kora → Aura/Hermes

Base: código real do repositório (não suposição). Footprint inicial: 170 arquivos com
`kora` no nome, ~1716 referências. Este documento justifica a remoção e mapeia substitutos.

## 1. O que a Kora fazia (verificado no código)

Pacote Python `packages/kora/` + módulo `modules/nixos/services/kora/` + CLI `kryonix kora`.

- **Gateway/API** (`kora-api`, FastAPI HTTP em `kryonix.services.kora.port`): rotas
  `/health`, `/chat`, `/chat/stream`, `/memory/*`, `/audit` (`kora/api/routes_*`, `server.py`).
- **Chat/ask/stream**: `kryonix kora ask`, `/chat` e `/chat/stream` (SSE) — `kora.sh`, `core/orchestrator.py`, `core/router.py`.
- **Health/status/capabilities**: `kryonix kora health|status`, `core/capabilities.py`.
- **Integração Brain**: `kora/integrations/brain.py`, `core/grounding.py` (RAG/CAG).
- **Integração Ollama**: `kora/llm/ollama.py` (runtime de modelo).
- **Integração Neo4j**: `kora/memory/graph.py` (grafo/memória).
- **Memória**: search/status/recent/index/flush — `kora/memory/{search,indexer,queue,obsidian,models}.py`;
  CLI `kryonix kora memory search|status`.
- **Memory worker**: `kora-memory-worker` (systemd service + timer) → fila JSONL → Obsidian Vault.
- **Voz** (`kora-admin voice ...` + `kryonix.services.kora.voice`): devices, test-mic, transcribe,
  speak, identity, daemon, mute/unmute, wakeword, VAD, STT (whisper), TTS (piper/f5tts/edgetts) —
  `kora/voice/**`, `modules/nixos/services/kora/voice.nix`, `systemd.user kora-voice-listener`.
- **Mind/persona**: `kora/mind/**` (persona, constructor, dialogue policy, reflection).
- **Learning**: `kora/learning/**` (corrections, profile, style, privacy).
- **Audit/benchmark/grounding/schema**: `kora/audit/*`, `core/benchmark.py`, `core/grounding.py`, `brain/schema.py`.
- **CLI** `kryonix kora` (`main.sh` case `kora)`, `kora.sh`), túnel/latência.
- **systemd**: `kora.service`, `kora-memory-worker.service`, `kora-memory-worker.timer`.
- **Dados**: `/var/lib/kryonix/kora`; secrets `/etc/kryonix/kora.env`.

## 2. O que era ruim (avaliação técnica)

- **Misturava identidade (assistente) com backend/gateway** — a persona e o servidor HTTP
  viviam no mesmo domínio, dificultando a arquitetura limpa.
- **Nome competia** com Aura (interface) e Hermes (motor): risco de "segunda assistente paralela".
- **Responsabilidades muito acopladas**: voz + memória + gateway + CLI + auditoria + worker no
  mesmo pacote/serviço.
- **`KORA_*` espalhadas** (KORA_API_URL/OLLAMA/BRAIN/etc.) e `kora.env` paralelo ao `hermes.env`.
- **`kora.service` disputava espaço conceitual com Hermes**, com risco de conflito de porta/config.
- **Sem fallback multi-provider automático** (o router Aura agora cobre isso).
- **Manutenção duplicada**: Hermes (motor upstream mantido) faz o papel de agente melhor;
  docs/agentes Kora envelheciam rápido.

## 3. Mapa de substituição

| Kora antiga              | Substituto novo                                   |
|--------------------------|---------------------------------------------------|
| `kryonix kora ask`       | `kryonix aura` / `aura "..."`                     |
| `kora.service`           | `hermes` (motor) + camada `aura`                  |
| `KORA_API_KEY`/`kora.env`| `HERMES_ENV` (`/etc/kryonix/hermes.env`) + chaves de provider |
| `KORA_API_URL`           | `HERMES_CONFIG`/`HERMES_HOME` + router `aura`      |
| Persona Kora             | `/etc/kryonix/hermes/SOUL.md` (persona Aura)      |
| `kora memory search`     | Aura/Hermes + **Kryonix Brain** (RAG/GraphRAG)    |
| Voz Kora                 | camada de voz da Aura (**pendente**, ver §4)       |
| `kora audit`             | `hermes doctor` + auditoria Brain/Graph           |
| `kora-memory-worker`     | ingestão do Brain/Vault (**pendente**, ver §4)     |

## 4. Pendências reais (NÃO esconder regressões)

Funcionalidades da Kora **sem equivalente pronto** na Aura/Hermes hoje:

1. **Voz completa da Aura**: wakeword, VAD, STT (whisper), TTS (piper/f5tts/edgetts), identity
   voice, daemon push-to-talk, mute/unmute. (Existia em `kora/voice/**` + `f5-tts-server`.)
2. **Memory worker**: persistência incremental de memórias → Obsidian Vault (fila JSONL → indexer).
3. **Comandos específicos**: `memory recent/flush/index`, `audit`, `benchmark`, `grounding` ainda
   não têm CLI Aura equivalente.

> Decisão: o **f5-tts-server** (`features/f5-tts-server`) e o **Kryonix Brain** permanecem — a voz e a
> memória da Aura serão reconstruídas sobre eles numa fase futura. A remoção da Kora retira o
> *runtime* acoplado, registrando estas pendências antes.
