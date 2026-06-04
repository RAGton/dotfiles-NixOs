# Aura/Hermes — Configuração

Separação canônica (definida no módulo `kryonix.services.hermes`):

| Var            | Caminho                          | Conteúdo                                  |
|----------------|----------------------------------|-------------------------------------------|
| `HERMES_HOME`  | `/var/lib/kryonix/hermes` (daemon); por-usuário no uso interativo | estado, sessão, `SOUL.md` |
| `HERMES_CONFIG`| `/etc/kryonix/hermes/config.yaml`| config declarativa **não-secreta** (versionada) |
| `HERMES_ENV`   | `/etc/kryonix/hermes.env`        | **secrets** (API keys) — modo 600, gitignored |

A config canônica **não depende mais** de `cli-config.yaml` dentro da venv (frágil, some
em rebuild). O wrapper `hermes` agora exporta `HERMES_CONFIG`/`HERMES_ENV` e um
`HERMES_HOME` gravável (corrige o `config not found` do banner).

## Persona Aura
`/etc/kryonix/hermes/SOUL.md` (versionado, não-secreto) define a identidade "Aura". O módulo
faz symlink declarativo `HERMES_HOME/SOUL.md → /etc/kryonix/hermes/SOUL.md` (tmpfiles `L+`).

## Secrets
Copie o template e preencha (nunca versione o arquivo real):

```bash
sudo install -m 600 /dev/null /etc/kryonix/hermes.env
sudo $EDITOR /etc/kryonix/hermes.env      # baseado em /etc/kryonix/hermes.env.example
```

Chaves: `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`/`GOOGLE_API_KEY`, `OPENAI_API_KEY`/`CODEX_API_KEY`.
Roteamento: `HERMES_PROVIDER_PRIMARY` (default `claude`), `HERMES_PROVIDER_FALLBACKS`
(default `gemini,codex,openai`). Modelos: `AURA_MODEL_{CLAUDE,GEMINI,CODEX,OPENAI}`.

## NixOS (módulo)
`kryonix.services.hermes` ganhou a opção `configFile` (default acima) e expõe os comandos
`hermes` e `aura`. `role=server` (glacier) sobe o daemon gateway; `role=client` só os comandos.
Atualizar o motor: `nix flake update hermes-agent`; rollback: reverter `flake.lock`.
