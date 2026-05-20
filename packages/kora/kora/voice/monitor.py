import logging

import httpx
from tenacity import before_sleep_log, retry, stop_never, wait_random_exponential

from ..core.config import OLLAMA_URL, KORA_API_URL

logger = logging.getLogger("kora.voice.monitor")

# Checked in order; True if any responds with status < 500.
_HEALTH_URLS = [
    f"{OLLAMA_URL}/api/version",  # Ollama — primary LLM backend
    f"{KORA_API_URL}/health",      # Kora API server
]

# Exponential backoff: starts at 1s, doubles with jitter, caps at 60s.
# Applied to coroutines that establish connections (e.g. _reconnect_probe).
retry_connection = retry(
    wait=wait_random_exponential(multiplier=1, min=1, max=60),
    stop=stop_never,
    before_sleep=before_sleep_log(logger, logging.WARNING),
    reraise=True,
)


async def ping_orchestrator(timeout: float = 5.0) -> bool:
    """Return True if at least one backend endpoint is reachable."""
    async with httpx.AsyncClient(timeout=timeout) as client:
        for url in _HEALTH_URLS:
            try:
                r = await client.get(url)
                if r.status_code < 500:
                    return True
            except Exception:
                continue
    return False
