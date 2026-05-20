import logging
import shutil
import subprocess
import wave
from pathlib import Path

from . import TTSProvider

logger = logging.getLogger("kora.voice.providers.spdsay")


class SPDSayProvider(TTSProvider):
    name = "spd-say"

    def health(self) -> bool:
        return shutil.which("spd-say") is not None

    async def synthesize(self, text: str, out_wav: Path) -> None:
        spd = shutil.which("spd-say")
        if not spd:
            raise RuntimeError("spd-say não encontrado no PATH")
        subprocess.run([spd, text], timeout=10)
        # spd-say reproduz diretamente; escreve silêncio para satisfazer a interface
        with wave.open(str(out_wav), "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(22050)
            wf.writeframes(b"\x00" * int(22050 * 2 * 0.1))
