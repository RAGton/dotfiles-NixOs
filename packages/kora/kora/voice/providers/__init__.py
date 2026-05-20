import os
from abc import ABC, abstractmethod
from pathlib import Path


class TTSProvider(ABC):
    name: str
    max_latency_s: float = 5.0

    @abstractmethod
    async def synthesize(self, text: str, out_wav: Path) -> None: ...

    @abstractmethod
    def health(self) -> bool: ...


def build_provider_chain(config: dict) -> TTSProvider:
    """Constrói cadeia F5TTS → Piper → EdgeTTS → spd-say conforme config/preset."""
    from .piper import PiperProvider
    from .f5tts import F5TTSProvider
    from .edgetts import EdgeTTSProvider
    from .spdsay import SPDSayProvider
    from .fallback import FallbackProvider
    from ..config import KORA_VOICE_TTS_BACKEND

    from .cache import CacheProvider

    provider_name = config.get("provider") or KORA_VOICE_TTS_BACKEND

    spd   = SPDSayProvider()
    edge  = EdgeTTSProvider(voice=config.get("voice", "pt-BR-FranciscaNeural"))
    piper = PiperProvider(config)

    if provider_name == "piper":
        chain = FallbackProvider([piper, edge, spd])
    else:
        f5 = F5TTSProvider(
            endpoint  = (os.environ.get("KORA_F5TTS_ENDPOINT")
                         or config.get("f5tts_endpoint",  "http://rve-glacier:7860")
                         or "http://rve-glacier:7860"),
            ref_audio = (os.environ.get("KORA_VOICE_REFERENCE")
                         or config.get("voice_reference", "/var/lib/f5-tts/voices/kora.wav")
                         or "/var/lib/f5-tts/voices/kora.wav"),
            ref_text  = config.get("voice_reference_text", ""),
        )
        # "f5tts" e "auto" têm o mesmo chain; "auto" é o padrão futuro via voice.nix
        chain = FallbackProvider([f5, piper, edge, spd])

    if config.get("cacheEnabled", True):
        cache_dir = config.get("cacheDir", "/var/cache/kora/tts")
        limit_mb = config.get("cacheLimitMB", 500)
        return CacheProvider(chain, cache_dir=cache_dir, limit_mb=limit_mb)

    return chain

