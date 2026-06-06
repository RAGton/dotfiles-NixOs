# Kryonix — Estratégia de LLMs Locais

## Objetivo

Rodar LLMs locais no Glacier com privacidade, custo controlado e estabilidade operacional.

## Hardware alvo

- CPU: Ryzen 7 9700X
- GPU: NVIDIA RTX 4060 8 GB VRAM
- Runtime principal: Ollama / llama.cpp
- Runtime futuro para serving pesado: vLLM, somente se houver GPU/RAM suficiente

## Perfis de modelo

### fast/default

Modelo principal:

```txt
qwen3:8b
```

Uso:

- Kryonix Brain padrão
- RAG
- automação
- tool calling leve
- chat técnico
- resposta rápida

### fallback/edge

Modelo leve:

```txt
gemma4:e2b
```

Uso:

- fallback
- tarefas pequenas
- baixa latência
- economia de VRAM/RAM

### deep/on-demand

Modelo pesado:

```txt
qwen3:30b
```

Uso:

- análise profunda
- revisão de arquitetura
- coding mais pesado
- somente sob demanda

### experimental

Modelo experimental:

```txt
glm-4.7-flash:q4_K_M
```

Uso:

- testes de agente
- comparação com Qwen
- não usar como padrão até validar latência, RAM e estabilidade

## Regras

- Não carregar modelo pesado automaticamente no boot.
- Não expor Ollama na internet pública.
- Usar Tailscale/LAN para acesso remoto.
- Validar GPU with nvidia-smi/nvtop.
- Medir tokens/s, p95 e uso de VRAM.
- Preferir modelo menor + RAG bom em vez de modelo grande sem contexto.
- Registrar resultados no Vault/Neo4j.

## Métricas obrigatórias

Para cada modelo testado, registrar:

- tamanho em disco
- VRAM usada
- RAM usada
- tokens/s
- latência primeira resposta
- qualidade em tarefas Kryonix
- qualidade em tool calling
- estabilidade com contexto longo

## Comandos base

```bash
ollama list
ollama run qwen3:8b "Kryonix smoke test"
curl -s http://127.0.0.1:11434/api/tags | jq
nvidia-smi
journalctl -u ollama -n 100 --no-pager
```
