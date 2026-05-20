import hashlib
import logging
import os
import shutil
import asyncio
from pathlib import Path
from . import TTSProvider

logger = logging.getLogger("kora.voice.providers.cache")

_warmed_up = False


class CacheProvider(TTSProvider):
    name = "cache"

    def __init__(self, delegate: TTSProvider, cache_dir: str = "/var/cache/kora/tts", limit_mb: int = 500) -> None:
        self._delegate = delegate
        # Resolve writable cache dir (fallback to home ~/.cache if PermissionError/etc)
        self.cache_dir = Path(cache_dir)
        try:
            self.cache_dir.mkdir(parents=True, exist_ok=True)
        except Exception:
            self.cache_dir = Path.home() / ".cache" / "kora" / "tts"
            try:
                self.cache_dir.mkdir(parents=True, exist_ok=True)
            except Exception:
                pass
        self.limit_bytes = limit_mb * 1024 * 1024

        # Trigger background warmup exactly once
        global _warmed_up
        if not _warmed_up:
            _warmed_up = True
            try:
                loop = asyncio.get_running_loop()
                if loop.is_running():
                    loop.create_task(self.warmup_cache())
            except RuntimeError:
                # No active loop in current thread; we can defer or execute safely
                pass

    def health(self) -> bool:
        return self._delegate.health()

    def _get_voice_ref(self) -> str:
        # Detect voice/model reference identifier to isolate cache keys
        if hasattr(self._delegate, "_ref_audio"):
            return str(getattr(self._delegate, "_ref_audio"))
        if hasattr(self._delegate, "voice"):
            return str(getattr(self._delegate, "voice"))
        if hasattr(self._delegate, "_voice"):
            return str(getattr(self._delegate, "_voice"))
        if hasattr(self._delegate, "_model_path"):
            return str(getattr(self._delegate, "_model_path"))
        return ""

    def _get_hash(self, text: str) -> str:
        provider_name = self._delegate.name
        voice_ref = self._get_voice_ref()
        key = f"{text.strip()}:{provider_name}:{voice_ref}"
        return hashlib.sha256(key.encode("utf-8")).hexdigest()

    async def synthesize(self, text: str, out_wav: Path) -> None:
        text_clean = text.strip()
        if not text_clean:
            return

        h = self._get_hash(text_clean)
        cache_path = self.cache_dir / f"{h}.wav"

        if cache_path.exists():
            logger.info("[CACHE HIT] text='%s' hash=%s", text_clean, h)
            # Update access time (LRU)
            try:
                os.utime(cache_path, None)
            except Exception:
                pass
            shutil.copy(cache_path, out_wav)
            return

        logger.info("[CACHE MISS] text='%s' hash=%s. Synthesizing...", text_clean, h)
        await self._delegate.synthesize(text, out_wav)

        if out_wav.exists() and out_wav.stat().st_size > 44:
            # Evict if needed before writing new file
            sz = out_wav.stat().st_size
            self._evict_if_needed(sz)
            try:
                shutil.copy(out_wav, cache_path)
                logger.info("[CACHE SAVE] Saved to %s", cache_path.name)
            except Exception as exc:
                logger.warning("[CACHE ERROR] Failed to save cache file: %s", exc)

    def _evict_if_needed(self, new_file_size: int = 0) -> None:
        files = []
        total_size = 0
        for p in self.cache_dir.glob("*.wav"):
            try:
                stat = p.stat()
                files.append((p, stat.st_atime, stat.st_size))
                total_size += stat.st_size
            except FileNotFoundError:
                continue

        # Sort by atime (oldest first)
        files.sort(key=lambda x: x[1])

        while total_size + new_file_size > self.limit_bytes and files:
            p_to_del, _, sz = files.pop(0)
            try:
                p_to_del.unlink()
                total_size -= sz
                logger.info("[CACHE EVICT] Removed old cache file %s (%d bytes)", p_to_del.name, sz)
            except Exception as exc:
                logger.warning("[CACHE EVICT ERROR] Failed to delete %s: %s", p_to_del, exc)

    async def warmup_cache(self) -> None:
        phrases = [
            "Claro!",
            "Deixa eu ver...",
            "Pronto!",
            "Hmm...",
            "Tá bem",
            "Posso ajudar em algo mais?",
            "Não entendi, repete por favor?",
        ]
        logger.info("[CACHE WARMUP] Iniciando pré-aquecimento do cache de TTS...")
        for phrase in phrases:
            h = self._get_hash(phrase)
            cache_path = self.cache_dir / f"{h}.wav"
            if cache_path.exists():
                continue
            try:
                import tempfile
                with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
                    temp_path = Path(f.name)
                # Synthesize directly bypassing read-cache to populate
                await self._delegate.synthesize(phrase, temp_path)
                if temp_path.exists() and temp_path.stat().st_size > 44:
                    self._evict_if_needed(temp_path.stat().st_size)
                    shutil.copy(temp_path, cache_path)
                    logger.info("[CACHE WARMUP SAVE] Aquecido: '%s' -> %s", phrase, cache_path.name)
                if temp_path.exists():
                    temp_path.unlink()
            except Exception as exc:
                logger.warning("[CACHE WARMUP ERROR] Falha ao aquecer frase '%s': %s", phrase, exc)
        logger.info("[CACHE WARMUP] Pré-aquecimento do cache de TTS concluído.")
