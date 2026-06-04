#!/usr/bin/env bash
# =============================================================================
# hermes-providers-doctor.sh — diagnóstico dos providers da Aura/Hermes.
# Nunca imprime valores de secrets; só presença/ausência das chaves.
# Preferência: delega ao `aura providers doctor`. Fallback: checagem mínima.
# =============================================================================
set -uo pipefail

if command -v aura >/dev/null 2>&1; then
  exec aura providers doctor
fi

echo "Comando 'aura' não encontrado (habilite kryonix.services.hermes e rebuild)." >&2
echo "Checagem mínima de chaves (apenas nomes, nunca valores):"
ENV_FILE="${HERMES_ENV:-/etc/kryonix/hermes.env}"
if [ -r "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090,SC1091
  . "$ENV_FILE"
  set +a
else
  echo "  (env não legível: $ENV_FILE)"
fi
for v in ANTHROPIC_API_KEY GEMINI_API_KEY GOOGLE_API_KEY OPENAI_API_KEY CODEX_API_KEY; do
  if [ -n "${!v:-}" ]; then echo "  $v: presente"; else echo "  $v: ausente"; fi
done
echo "Primary=${HERMES_PROVIDER_PRIMARY:-claude}  Fallbacks=${HERMES_PROVIDER_FALLBACKS:-gemini,codex,openai}"
