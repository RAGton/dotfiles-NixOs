"""
Testes unitários dos providers TTS da Kora.

Cobre: fallback, cache hit, silêncio de emergência e carregamento do preset F5-TTS.
"""

import asyncio
import wave
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import pytest


# ─── helpers ────────────────────────────────────────────────────────────────

def _make_wav(path: Path) -> None:
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(22050)
        wf.writeframes(b"\x00" * 200)


# ─── testes ─────────────────────────────────────────────────────────────────

def test_fallback_acionado_quando_f5tts_retorna_500(tmp_path):
    """F5TTS falha → FallbackProvider deve tentar PiperProvider."""
    from kora.voice.providers.fallback import FallbackProvider

    f5_mock = MagicMock()
    f5_mock.name = "f5tts"
    f5_mock.health.return_value = True
    f5_mock.synthesize = AsyncMock(side_effect=RuntimeError("HTTP 500"))

    piper_mock = MagicMock()
    piper_mock.name = "piper"
    piper_mock.health.return_value = True

    async def piper_synth(text, out_wav):
        _make_wav(out_wav)

    piper_mock.synthesize = AsyncMock(side_effect=piper_synth)

    chain = FallbackProvider([f5_mock, piper_mock])
    out = tmp_path / "out.wav"
    asyncio.run(chain.synthesize("teste de fallback", out))

    piper_mock.synthesize.assert_called_once()
    assert out.exists()


def test_cache_hit_pula_provider(tmp_path):
    """Segunda síntese da mesma frase não chama o provider — usa cache."""
    import kora.voice.providers.cache as cache_mod
    from kora.voice.providers.cache import CacheProvider

    delegate = MagicMock()
    delegate.name = "mock"
    delegate.health.return_value = True
    delegate._ref_audio = "/var/lib/f5-tts/voices/kora.wav"

    async def fake_synth(text, out_wav):
        _make_wav(out_wav)

    delegate.synthesize = AsyncMock(side_effect=fake_synth)

    # Cria o cache fora do asyncio.run para que get_running_loop() lance
    # RuntimeError e o warmup automático seja suprimido.
    cache_mod._warmed_up = False
    cache = CacheProvider(delegate, cache_dir=str(tmp_path), limit_mb=10)

    async def _run():
        out1 = tmp_path / "out1.wav"
        out2 = tmp_path / "out2.wav"
        await cache.synthesize("Olá, Kora.", out1)
        await cache.synthesize("Olá, Kora.", out2)

    asyncio.run(_run())

    assert delegate.synthesize.call_count == 1


def test_kora_nunca_fica_muda(tmp_path):
    """Quando todos os providers falham, _write_silence é chamado."""
    from kora.voice.providers.fallback import FallbackProvider

    out = tmp_path / "out.wav"
    with patch("kora.voice.providers.fallback._write_silence") as mock_silence:
        asyncio.run(FallbackProvider([]).synthesize("silêncio", out))
        mock_silence.assert_called_once_with(out)


def test_f5tts_preset_carregado_corretamente():
    """build_provider_chain com provider='f5tts' coloca F5TTSProvider na frente."""
    from kora.voice.providers import build_provider_chain
    from kora.voice.providers.f5tts import F5TTSProvider
    from kora.voice.providers.fallback import FallbackProvider

    chain = build_provider_chain({"provider": "f5tts", "cacheEnabled": False})

    assert isinstance(chain, FallbackProvider)
    assert isinstance(chain._providers[0], F5TTSProvider)
