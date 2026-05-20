import json as _json
import logging
import urllib.error
import urllib.request
from pathlib import Path

from . import TTSProvider

logger = logging.getLogger("kora.voice.providers.f5tts")


class F5TTSProvider(TTSProvider):
    name = "f5tts"

    def __init__(self, endpoint: str, ref_audio: str, ref_text: str) -> None:
        self._endpoint  = endpoint.rstrip("/")
        self._ref_audio = ref_audio
        self._ref_text  = ref_text

    def health(self) -> bool:
        try:
            with urllib.request.urlopen(f"{self._endpoint}/health", timeout=2) as r:
                return r.status == 200
        except Exception:
            return False

    async def synthesize(self, text: str, out_wav: Path) -> None:
        payload = _json.dumps({
            "text":      text,
            "ref_audio": self._ref_audio,
            "ref_text":  self._ref_text,
        }).encode()
        req = urllib.request.Request(
            f"{self._endpoint}/synthesize",
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                out_wav.write_bytes(resp.read())
        except urllib.error.URLError as exc:
            raise RuntimeError(f"F5-TTS HTTP error: {exc}") from exc
