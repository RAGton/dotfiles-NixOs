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

    provider_name = config.get("provider") or KORA_VOICE_TTS_BACKEND

    spd   = SPDSayProvider()
    edge  = EdgeTTSProvider(voice=config.get("voice", "pt-BR-FranciscaNeural"))
    piper = PiperProvider(config)

    if provider_name == "piper":
        return FallbackProvider([piper, edge, spd])

    f5 = F5TTSProvider(
        endpoint  = config.get("f5tts_endpoint",       "http://rve-glacier:7860"),
        ref_audio = config.get("voice_reference",      "/var/lib/f5-tts/voices/kora.wav"),
        ref_text  = config.get("voice_reference_text", ""),
    )
    # "f5tts" e "auto" têm o mesmo chain; "auto" é o padrão futuro via voice.nix
    return FallbackProvider([f5, piper, edge, spd])
