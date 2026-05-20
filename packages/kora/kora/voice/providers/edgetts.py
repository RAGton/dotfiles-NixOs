import logging
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from . import TTSProvider

logger = logging.getLogger("kora.voice.providers.edgetts")


class EdgeTTSProvider(TTSProvider):
    name = "edge-tts"

    def __init__(self, voice: str = "pt-BR-FranciscaNeural") -> None:
        self._voice = voice

    def health(self) -> bool:
        try:
            import importlib.util
            return importlib.util.find_spec("edge_tts") is not None
        except Exception:
            return False

    async def synthesize(self, text: str, out_wav: Path) -> None:
        with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as f:
            mp3 = f.name
        try:
            # Run edge-tts in a subprocess to avoid event-loop conflicts
            code = (
                "import asyncio, edge_tts\n"
                "async def main():\n"
                f"    await edge_tts.Communicate({repr(text)}, {repr(self._voice)}).save({repr(mp3)})\n"
                "asyncio.run(main())\n"
            )
            subprocess.run(
                [sys.executable, "-c", code],
                check=True, capture_output=True, text=True, timeout=15,
            )

            ffmpeg = shutil.which("ffmpeg")
            if not ffmpeg:
                raise RuntimeError("ffmpeg ausente — não é possível converter mp3→wav")
            subprocess.run(
                [ffmpeg, "-y", "-i", mp3, "-ar", "22050", "-ac", "1", "-f", "wav", str(out_wav)],
                check=True, capture_output=True,
            )
        finally:
            if os.path.exists(mp3):
                os.unlink(mp3)
