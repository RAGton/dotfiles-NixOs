import json
import logging
import subprocess
import wave
from pathlib import Path

from . import TTSProvider

logger = logging.getLogger("kora.voice.providers.piper")


class PiperProvider(TTSProvider):
    name = "piper"

    def __init__(self, config: dict) -> None:
        self._config = config

    def health(self) -> bool:
        from ..tts import _find_piper_bin
        from ..config import PIPER_MODEL_PATH
        return bool(_find_piper_bin()) and Path(PIPER_MODEL_PATH).exists()

    async def synthesize(self, text: str, out_wav: Path) -> None:
        from ..tts import _find_piper_bin, aplicar_prosodia_artificial

        piper_bin = _find_piper_bin()
        if not piper_bin:
            raise RuntimeError("piper binary not found in PATH")

        model_path, cfg_path = self._resolve_model()
        if not model_path.exists():
            raise RuntimeError(f"Piper model not found: {model_path}")

        length_scale = self._config.get("length_scale", 1.1)
        sample_rate  = self._read_sample_rate(cfg_path)

        cmd = [piper_bin, "--model", str(model_path), "--output_raw",
               "--length_scale", str(length_scale)]
        if cfg_path and cfg_path.exists():
            cmd += ["--config", str(cfg_path)]
        if self._config.get("noise_scale"):
            cmd += ["--noise_scale", str(self._config["noise_scale"])]
        if self._config.get("noise_w"):
            cmd += ["--noise_w", str(self._config["noise_w"])]

        silence = b"\x00" * int(sample_rate * 2 * 0.2)
        chunks  = aplicar_prosodia_artificial(text) or [text]
        parts: list[bytes] = []

        for i, chunk in enumerate(chunks):
            proc = subprocess.run(cmd, input=chunk.encode(), capture_output=True)
            if proc.returncode == 0 and proc.stdout:
                parts.append(proc.stdout)
                if i < len(chunks) - 1:
                    parts.append(silence)

        if not parts:
            raise RuntimeError("Piper produced no audio output")

        with wave.open(str(out_wav), "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            wf.writeframes(b"".join(parts))

    def _resolve_model(self) -> tuple[Path, Path | None]:
        from ..config import PIPER_MODEL_PATH, PIPER_CONFIG_PATH
        name = self._config.get("model")
        if name:
            try:
                from ..models import PIPER_VOICES, PIPER_DIR
                if name in PIPER_VOICES:
                    meta = PIPER_VOICES[name]
                    p = PIPER_DIR / meta["local_model"]
                    if p.exists():
                        return p, PIPER_DIR / meta["local_config"]
            except Exception as exc:
                logger.debug("model lookup: %s", exc)
        return Path(PIPER_MODEL_PATH), Path(PIPER_CONFIG_PATH)

    def _read_sample_rate(self, cfg: Path | None) -> int:
        if cfg and cfg.exists():
            try:
                data = json.loads(cfg.read_text(encoding="utf-8"))
                sr = data.get("audio", {}).get("sample_rate")
                if sr:
                    return int(sr)
            except Exception:
                pass
        return 22050
