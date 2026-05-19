# =============================================================================
# Kora — Core Configuration
#
# Centraliza toda configuração da Kora via variáveis de ambiente.
# Segue o padrão do Brain config.py: defaults sensatos, override via env.
#
# Secrets:
#   KORA_API_KEY            → chave para clientes acessarem a Kora API
#   KRYONIX_BRAIN_API_KEY   → chave interna para Kora acessar o Brain
#   Nunca logar, nunca colocar no nix store.
# =============================================================================

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

# Load environment files
# Order of priority:
# 1. Environment variables already set (os.environ)
# 2. ~/.config/kryonix/kora.env
# 3. /etc/kryonix/kora.env
# 4. Standard .env file in CWD
user_env = Path.home() / ".config" / "kryonix" / "kora.env"
global_env = Path("/etc/kryonix/kora.env")

if user_env.exists():
    load_dotenv(user_env)
elif global_env.exists():
    try:
        load_dotenv(global_env)
    except Exception:
        pass

load_dotenv()

# ── Kora Service ─────────────────────────────────────────────────
KORA_HOST = os.getenv("KORA_HOST", "127.0.0.1")
KORA_PORT = int(os.getenv("KORA_PORT", "8787"))
KORA_DATA_DIR = Path(os.getenv("KORA_DATA_DIR", "/var/lib/kryonix/kora"))
KORA_SESSIONS_DIR = KORA_DATA_DIR / "sessions"
KORA_AUDIT_DIR = KORA_DATA_DIR / "audit"

# ── Auth ─────────────────────────────────────────────────────────
# KORA_API_KEY: protege a API pública da Kora (clientes externos)
# KRYONIX_BRAIN_API_KEY: usada internamente para Kora acessar Brain API
KORA_API_KEY = os.getenv("KORA_API_KEY", "")
BRAIN_API_KEY = os.getenv("KRYONIX_BRAIN_API_KEY", "")

# ── Ollama (model runtime) ───────────────────────────────────────
OLLAMA_URL = os.getenv("KORA_OLLAMA_URL", "http://127.0.0.1:11434")
OLLAMA_MODEL = os.getenv("KORA_MODEL", "qwen2.5-coder:7b")
OLLAMA_TIMEOUT_CHAT = int(os.getenv("KORA_OLLAMA_TIMEOUT_CHAT", "120"))
OLLAMA_TIMEOUT_HEALTH = int(os.getenv("KORA_OLLAMA_TIMEOUT_HEALTH", "5"))

# ── Brain API (knowledge backend) ────────────────────────────────
BRAIN_URL = os.getenv("KORA_BRAIN_URL", "http://127.0.0.1:8000")
BRAIN_TIMEOUT = int(os.getenv("KORA_BRAIN_TIMEOUT", "30"))

# ── Neo4j (graph/memory backend) ─────────────────────────────────
NEO4J_URI = os.getenv("KORA_NEO4J_URI", "bolt://127.0.0.1:7687")

# ── System Prompt ─────────────────────────────────────────────────
_PROMPT_FILE = Path(__file__).parent.parent / "llm" / "system_prompt.md"


def load_system_prompt() -> str:
    """Load the Kora system prompt from disk."""
    if _PROMPT_FILE.exists():
        return _PROMPT_FILE.read_text(encoding="utf-8").strip()
    return (
        "Você é a Kora, assistente pessoal local do ecossistema Kryonix. "
        "Responda de forma técnica, direta e útil em português do Brasil."
    )


# ── Ensure directories ───────────────────────────────────────────
def ensure_dirs() -> None:
    """Create runtime directories if they don't exist."""
    for d in (KORA_DATA_DIR, KORA_SESSIONS_DIR, KORA_AUDIT_DIR):
        try:
            d.mkdir(parents=True, exist_ok=True)
        except OSError:
            pass
