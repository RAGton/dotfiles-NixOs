import logging
import time
import wave
from pathlib import Path

from . import TTSProvider

logger = logging.getLogger("kora.voice.providers.fallback")

_SLOW_THRESHOLD = 3


class FallbackProvider(TTSProvider):
    name = "fallback"

    def __init__(self, providers: list[TTSProvider], max_latency_s: float = 5.0) -> None:
        self._providers    = providers
        self.max_latency_s = max_latency_s
        self._slow_streak: dict[str, int] = {}

    def health(self) -> bool:
        return any(p.health() for p in self._providers)

    def _demoted(self, p: TTSProvider) -> bool:
        return self._slow_streak.get(p.name, 0) >= _SLOW_THRESHOLD

    def _record(self, p: TTSProvider, elapsed: float) -> None:
        if elapsed > self.max_latency_s:
            self._slow_streak[p.name] = self._slow_streak.get(p.name, 0) + 1
            if self._demoted(p):
                logger.warning(
                    "%s demotado após %d chamadas lentas (última %.1fs)",
                    p.name, _SLOW_THRESHOLD, elapsed,
                )
        else:
            self._slow_streak[p.name] = 0

    async def synthesize(self, text: str, out_wav: Path) -> None:
        for p in self._providers:
            if not p.health():
                logger.debug("%s: health falhou, pulando", p.name)
                continue
            if self._demoted(p):
                logger.info("%s: demotado, pulando esta chamada", p.name)
                continue
            try:
                t0 = time.monotonic()
                await p.synthesize(text, out_wav)
                self._record(p, time.monotonic() - t0)
                return
            except Exception as exc:
                logger.warning("%s: falhou (%s), tentando próximo", p.name, exc)
                self._slow_streak[p.name] = _SLOW_THRESHOLD

        logger.error("Todos os providers TTS falharam; escrevendo silêncio")
        _write_silence(out_wav)


def _write_silence(path: Path, duration_s: float = 0.1, sr: int = 22050) -> None:
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sr)
        wf.writeframes(b"\x00" * int(sr * 2 * duration_s))
