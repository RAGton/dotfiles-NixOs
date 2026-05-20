import os
import shutil
import tempfile
import wave
import pytest
from pathlib import Path
from unittest.mock import MagicMock

from kora.voice.providers import TTSProvider
from kora.voice.providers.cache import CacheProvider


class DummyProvider(TTSProvider):
    name = "dummy"

    def __init__(self) -> None:
        self.synthesize_calls = 0
        self._ref_audio = "/path/to/kora.wav"

    def health(self) -> bool:
        return True

    async def synthesize(self, text: str, out_wav: Path) -> None:
        self.synthesize_calls += 1
        with wave.open(str(out_wav), "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(22050)
            wf.writeframes(b"\x00" * 200)  # simple fake wav of size 200 bytes


import asyncio

def test_cache_hit_and_miss():
    async def _run():
        with tempfile.TemporaryDirectory() as tmp_dir:
            delegate = DummyProvider()
            cache = CacheProvider(delegate, cache_dir=tmp_dir, limit_mb=10)

            # 1. Miss synthesis
            out_wav = Path(tmp_dir) / "output.wav"
            await cache.synthesize("Olá, tudo bem?", out_wav)

            assert out_wav.exists()
            assert delegate.synthesize_calls == 1
            
            # Verify that it is in the cache folder now
            cache_files = list(Path(tmp_dir).glob("*.wav"))
            # Exclude output.wav
            cache_files = [f for f in cache_files if f.name != "output.wav"]
            assert len(cache_files) == 1

            # 2. Hit synthesis (must reuse the cache and not call the delegate)
            out_wav2 = Path(tmp_dir) / "output2.wav"
            await cache.synthesize("Olá, tudo bem?", out_wav2)

            assert out_wav2.exists()
            assert delegate.synthesize_calls == 1  # Still 1 call to delegate!

    asyncio.run(_run())


def test_cache_eviction():
    async def _run():
        with tempfile.TemporaryDirectory() as tmp_dir, tempfile.TemporaryDirectory() as out_dir:
            delegate = DummyProvider()
            # limit_mb = 1 => 1MB = 1048576 bytes
            # Let's set a super tiny limit of 500 bytes to force eviction quickly!
            cache = CacheProvider(delegate, cache_dir=tmp_dir, limit_mb=1)
            # Manually force limit_bytes to 300 bytes for testing
            cache.limit_bytes = 300

            # Each synthesis generates 200 bytes of audio plus 44 bytes header = 244 bytes
            # 1. First phrase (244 bytes)
            w1 = Path(out_dir) / "w1.wav"
            await cache.synthesize("Phrase One", w1)

            # 2. Second phrase (244 bytes) -> triggers eviction of Phrase One because 244 + 244 = 488 > 300 limit!
            w2 = Path(out_dir) / "w2.wav"
            await cache.synthesize("Phrase Two", w2)

            # Let's check which files are in the cache directory
            cache_files = [f.name for f in Path(tmp_dir).glob("*.wav")]
            assert len(cache_files) == 1  # Only one file kept, the other got evicted!

    asyncio.run(_run())


