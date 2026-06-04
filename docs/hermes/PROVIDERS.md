# Aura/Hermes — Providers

A **Aura** é a camada Kryonix por cima do motor **Hermes** (NousResearch, MIT),
consumido como **flake input pinado** (`inputs.hermes-agent`, `flake.lock`). O motor
não é forkado nem renomeado — atualiza via `nix flake update hermes-agent` e faz
rollback revertendo o `flake.lock`.

## Arquitetura

```
Aura (camada Kryonix)            -> comando `aura` / `kryonix aura`
  ├─ router de fallback          -> packages/aura/aura.sh
  └─ motor Hermes (`hermes`)     -> modules/nixos/services/hermes.nix (uv venv)
        ├─ Claude   (anthropic)
        ├─ Gemini   (google)
        ├─ Codex    (codex)
        └─ OpenAI   (openai)
```

`aura` chama o comando `hermes` (wrapper do módulo), que cuida do venv/env. O Hermes
traz catálogo nativo de providers (models.dev) com transports `anthropic_messages`,
`openai_chat` e `codex_responses`.

## Mapeamento provider → Hermes

| Aura provider | `hermes --provider` | chave (env)                      | modelo (env)         |
|---------------|---------------------|----------------------------------|----------------------|
| claude        | anthropic           | `ANTHROPIC_API_KEY`              | `AURA_MODEL_CLAUDE`  |
| gemini        | google              | `GEMINI_API_KEY` ou `GOOGLE_API_KEY` | `AURA_MODEL_GEMINI` |
| codex         | codex               | `CODEX_API_KEY` ou `OPENAI_API_KEY` | `AURA_MODEL_CODEX` |
| openai        | openai              | `OPENAI_API_KEY`                 | `AURA_MODEL_OPENAI`  |

> Os **ids de modelo** são **configuráveis por env** (não hardcoded) porque dependem
> do catálogo real do `hermes`. Ajuste em `/etc/kryonix/hermes.env`. Provider sem
> chave é **ignorado** (não é erro fatal).

## Comandos

```bash
aura "sua mensagem"          # chat roteado (Claude→Gemini→Codex/OpenAI)
aura providers list          # providers + presença de chave (nunca o valor)
aura providers doctor        # diagnóstico + `hermes doctor` (secrets redatados)
aura providers test claude   # teste mínimo de um provider
aura config show | path      # config canônica
hermes ...                   # motor direto (debug/admin), inalterado
```
