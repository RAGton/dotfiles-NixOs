# Aura/Hermes — Política de Fallback

O fallback **não é nativo** do Hermes (o `model_switch` só resolve alias→provider). A
Aura implementa o roteamento **fora do core**, no `packages/aura/aura.sh` (camada Kryonix),
preservando o upstream para receber updates.

## Ordem
`HERMES_PROVIDER_PRIMARY` (default `claude`) → `HERMES_PROVIDER_FALLBACKS`
(default `gemini,codex,openai`). Provider **sem chave** é ignorado com aviso
(`Provider X ignorado: <KEY> ausente.`) — nunca fatal se houver outro saudável.

## Classificação do erro

| Classe        | Padrões (case-insensitive)                                              | Ação |
|---------------|-------------------------------------------------------------------------|------|
| **fallback**  | rate_limit, 429, quota, temporary/temporariamente, timeout, overloaded, server_error, 500/502/503 | tenta o **próximo** provider |
| **context**   | context_length_exceeded, "context length", "maximum context"            | o Hermes já compacta nativamente antes de estourar; se ainda estourou → próximo provider |
| **stop**      | invalid_api_key, 401, unauthorized, permission_denied, 403, forbidden, safety/blocked, malformed, "bad request", 400 | **não** faz fallback; reporta o erro real |
| **unknown**   | qualquer outro                                                          | re-tenta (até 2x, backoff 2s); se persistir, alterna e mostra o erro |

Mensagens (sem vazar chave):
```
Provider claude ignorado: ANTHROPIC_API_KEY ausente.
claude indisponível por rate_limit/quota/timeout/server_error. Aura alternando para o próximo provider.
Provider gemini falhou com erro não-recuperável; não faço fallback.   # ex.: invalid_api_key
```

## context_length
Tratado **antes** do fallback pela compactação nativa do Hermes (configurável no motor). O
router só alterna de provider quando a compactação nativa não resolveu — evitando perder
contexto desnecessariamente.

## Segurança
- Chaves só em `HERMES_ENV`; o router carrega em memória e **nunca** ecoa valores
  (`security.redact_secrets: true` no `config.yaml` + redação no wrapper).
- Não repetir ação destrutiva em fallback sem confirmação (regra do `SOUL.md`).
- Retry por provider: 2 tentativas, backoff 2s.
