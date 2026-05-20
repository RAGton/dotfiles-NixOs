# =============================================================================
# Kora Voice — Wake-word Detection
# =============================================================================

import logging
import numpy as np
import os
import sys
from pathlib import Path

try:
    import scipy.signal  # noqa: F401  — only used as a capability probe
    SCIPY_AVAILABLE = True
except ImportError:
    SCIPY_AVAILABLE = False

logger = logging.getLogger("kora.voice.wakeword")

# ---------------------------------------------------------------------------
# Backend detection — two separate backends, incompatible APIs
# ---------------------------------------------------------------------------

# Backend A: the real "openwakeword" PyPI package (not in nixpkgs).
# API: Model(wakeword_models=[...]) / Model(model_names=[...]) + model.predict(np_array)

# Backend B: "pyopen-wakeword" (nixpkgs).
# API: OpenWakeWord.from_builtin(Model_enum) + OpenWakeWordFeatures.from_builtin()
#      Then: for features in oww_features.process_streaming(bytes): for prob in oww.process_streaming(features)

from typing import Any

OPENWAKEWORD_BACKEND: str | None = None
OPENWAKEWORD_AVAILABLE = False

# Resolved at import time; typed as Any to avoid None-call errors in static analysis.
_OWW_Model: Any = None
_PyOWW_OpenWakeWord: Any = None
_PyOWW_OpenWakeWordFeatures: Any = None
_PyOWW_Model: Any = None

try:
    from openwakeword.model import Model as _OWW_Model  # type: ignore[import]
    OPENWAKEWORD_BACKEND = "openwakeword"
    OPENWAKEWORD_AVAILABLE = True
    logger.debug("Wake-word backend: openwakeword (real package)")
except ImportError:
    pass

if not OPENWAKEWORD_AVAILABLE:
    try:
        from pyopen_wakeword import OpenWakeWord as _PyOWW_OpenWakeWord  # type: ignore[import]
        from pyopen_wakeword import OpenWakeWordFeatures as _PyOWW_OpenWakeWordFeatures  # type: ignore[import]
        from pyopen_wakeword.const import Model as _PyOWW_Model  # type: ignore[import]
        OPENWAKEWORD_BACKEND = "pyopen_wakeword"
        OPENWAKEWORD_AVAILABLE = True
        logger.debug("Wake-word backend: pyopen_wakeword (nixpkgs TFLite)")
    except ImportError:
        logger.warning("No wake-word backend found. Wake-word detection disabled.")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _resample_to_16khz(audio_data: bytes, input_rate: int) -> bytes:
    if input_rate == 16000:
        return audio_data

    if not SCIPY_AVAILABLE:
        logger.warning("scipy unavailable — cannot resample %dHz→16kHz", input_rate)
        return audio_data

    try:
        audio_np = np.frombuffer(audio_data, dtype=np.int16)
        gcd_val = np.gcd(16000, input_rate)
        up = 16000 // gcd_val
        down = input_rate // gcd_val
        from scipy.signal import resample_poly, resample as _scipy_resample
        if up < 100 and down < 100:
            resampled = resample_poly(audio_np, up, down)
        else:
            num_samples = int(len(audio_np) * 16000 / input_rate)
            resampled = _scipy_resample(audio_np, num_samples)
        resampled = np.clip(resampled, -32768, 32767).astype(np.int16)
        return resampled.tobytes()
    except Exception as exc:
        logger.error("Resample error %dHz→16kHz: %s", input_rate, exc)
        return audio_data


# ---------------------------------------------------------------------------
# KoraWakeWord — unified detection class over both backends
# ---------------------------------------------------------------------------

# Built-in models bundled by pyopen_wakeword (fallback priority order)
_PYOWW_FALLBACK_MODELS = ["hey_mycroft", "hey_jarvis", "okay_nabu", "hey_rhasspy"]


class KoraWakeWord:
    def __init__(self, model: str = "kora") -> None:
        self.model_name = model
        self.active = False
        self.oww_model: Any = None          # detection model instance
        self.oww_features: Any = None       # feature extractor (pyopen_wakeword only)
        self.ready = False
        self.input_rate = 16000
        self._backend = OPENWAKEWORD_BACKEND

        if self._backend == "openwakeword":
            self._init_openwakeword()
        elif self._backend == "pyopen_wakeword":
            self._init_pyopen_wakeword()
        else:
            logger.warning("No wake-word backend — running in foundation (no detection) mode.")

    # --- openwakeword (real PyPI package) -----------------------------------

    def _init_openwakeword(self) -> None:
        for kwargs in [
            {"wakeword_models": [self.model_name]},
            {"model_names": [self.model_name]},
        ]:
            try:
                self.oww_model = _OWW_Model(**kwargs)
                loaded = list(getattr(self.oww_model, "models", {}).keys()) or [self.model_name]
                logger.info("openwakeword initialized (models: %s)", loaded)
                self.ready = True
                return
            except TypeError:
                continue
            except Exception as exc:
                logger.warning("openwakeword init failed for '%s': %s", self.model_name, exc)
                break

        # Fallback to hey_mycroft
        for kwargs in [{"wakeword_models": ["hey_mycroft"]}, {"model_names": ["hey_mycroft"]}]:
            try:
                self.oww_model = _OWW_Model(**kwargs)
                self.model_name = "hey_mycroft"
                logger.info("openwakeword initialized with fallback model 'hey_mycroft'")
                self.ready = True
                return
            except Exception:
                continue

        logger.error("openwakeword: all init attempts failed — no detection.")

    # --- pyopen_wakeword (nixpkgs TFLite backend) ---------------------------

    def _init_pyopen_wakeword(self) -> None:
        try:
            self.oww_features = _PyOWW_OpenWakeWordFeatures.from_builtin()
        except Exception as exc:
            logger.error("pyopen_wakeword: feature extractor init failed: %s", exc)
            return

        for model_name in _PYOWW_FALLBACK_MODELS:
            try:
                model_enum = _PyOWW_Model(model_name)
                self.oww_model = _PyOWW_OpenWakeWord.from_builtin(model_enum)
                self.model_name = model_name
                logger.info("pyopen_wakeword: using built-in model '%s'", model_name)
                self.ready = True
                return
            except Exception as exc:
                logger.warning("pyopen_wakeword: failed to load '%s': %s", model_name, exc)

        logger.error("pyopen_wakeword: no built-in model could be loaded — no detection.")

    # --- common -------------------------------------------------------------

    def start(self) -> None:
        self.active = True
        logger.info("Wake-word detection enabled (backend=%s model=%s)", self._backend, self.model_name)

    def stop(self) -> None:
        self.active = False
        logger.info("Wake-word detection disabled.")

    def detect(self, audio_data: bytes) -> bool:
        """Return True if the wake-word is detected in this audio chunk."""
        if not self.ready or not self.active:
            return False

        try:
            audio_data = _resample_to_16khz(audio_data, self.input_rate)

            if self._backend == "openwakeword":
                audio_np = np.frombuffer(audio_data, dtype=np.int16)
                prediction = self.oww_model.predict(audio_np)
                for mdl, score in prediction.items():
                    if score > 0.75:
                        logger.info("Wake-word: %s (score=%.2f)", mdl, score)
                        return True

            elif self._backend == "pyopen_wakeword":
                for features in self.oww_features.process_streaming(audio_data):
                    for prob in self.oww_model.process_streaming(features):
                        if prob > 0.5:
                            logger.info("Wake-word: %s (score=%.2f)", self.model_name, prob)
                            return True

        except Exception as exc:
            logger.error("Wake-word detection error: %s", exc)

        return False


# ---------------------------------------------------------------------------
# Status helper (used by /voice status endpoint)
# ---------------------------------------------------------------------------

def get_wakeword_status() -> dict:
    if not OPENWAKEWORD_AVAILABLE:
        return {
            "target_wake_word": "none",
            "backend": "none (no library found)",
            "custom_kora_model": "missing",
            "status": "unavailable",
            "ready": False,
            "note": "Install openwakeword or pyopen-wakeword.",
        }

    # Quick probe — don't keep the model alive
    probe = KoraWakeWord("kora")
    return {
        "target_wake_word": probe.model_name,
        "backend": OPENWAKEWORD_BACKEND or "none",
        "custom_kora_model": "present" if probe.model_name == "kora" else "missing (using fallback)",
        "status": "ready" if probe.ready else "error",
        "ready": probe.ready,
        "note": "Usando modelo embutido como fallback — modelo 'kora' não encontrado."
                if probe.model_name != "kora" else "Modelo customizado 'kora' carregado.",
    }


# ---------------------------------------------------------------------------
# Whisper-based keyword detector (primary trigger for daemon)
# ---------------------------------------------------------------------------

import os as _os
_WAKE_WORD = _os.environ.get("KORA_WAKE_WORD", "kora").lower()

# Common Whisper misrecognitions of "Kora" in Portuguese audio
_WAKE_ALIASES = {"kora", "cora", "corra", "hora", "korá", "corá"}


def _keyword_detect(audio_data: bytes) -> bool:
    """
    Transcribe a short audio segment with faster-whisper and return True
    if the configured wake word (or a common alias) is present.

    Called in a thread-pool executor — must be thread-safe.
    """
    import os
    import wave
    import tempfile

    if len(audio_data) < 960:  # less than one 30ms chunk — skip
        return False

    tmp_path: str | None = None
    try:
        from .stt import transcribe_audio  # lazy import — model loads once

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            tmp_path = f.name
        with wave.open(tmp_path, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)  # 16-bit
            wf.setframerate(16000)
            wf.writeframes(audio_data)

        text = transcribe_audio(tmp_path)
        if not text:
            return False

        normalized = text.strip().lower()
        aliases = _WAKE_ALIASES | {_WAKE_WORD}
        for alias in aliases:
            if alias in normalized:
                logger.info("Keyword '%s' found in %r", alias, text[:60])
                return True

    except Exception as exc:
        logger.error("_keyword_detect: %s", exc)
    finally:
        if tmp_path:
            try:
                os.unlink(tmp_path)
            except Exception:
                pass

    return False


# ---------------------------------------------------------------------------
# WakeWordEngine — stdin-pipe facade used by daemon.py
# ---------------------------------------------------------------------------

# 960 bytes = 480 samples = 30ms at 16kHz s16 — valid webrtcvad frame.
_CHUNK_BYTES = 960


class _NoOpStream:
    """Backward-compat stub — daemon.py used to call engine.stream.close()."""
    def close(self) -> None:
        pass


class WakeWordEngine:
    """
    Wake-word engine that reads raw 16kHz s16 mono PCM from stdin.

    Expected invocation (set up by the systemd unit):
        pw-record --channels 1 --rate 16000 --format s16 --raw - \\
            | kora-admin voice daemon run

    No PyAudio / PortAudio is used; all hardware interaction lives in
    pw-record, which avoids the GLIBC double-free / SIGABRT bugs.
    """

    def __init__(self, model: str = "kora") -> None:
        self.detector = KoraWakeWord(model)
        self.detector.start()
        self.detector.input_rate = 16000
        self.lock_path = Path(f"/run/user/{os.getuid()}/kryonix/voice.lock")
        self.stream = _NoOpStream()
        logger.info("WakeWordEngine: stdin mode active (pw-record → pipe → kora)")

    def is_locked(self) -> bool:
        return self.lock_path.exists()

    def listen(self) -> bool:
        """Read one 30ms chunk from stdin and run wake-word detection (PTT path)."""
        try:
            data = sys.stdin.buffer.read(_CHUNK_BYTES)
        except Exception as exc:
            logger.error("WakeWordEngine: stdin read error: %s", exc)
            return False

        if not data:
            logger.warning("WakeWordEngine: stdin EOF — pw-record may have exited")
            return False

        if self.is_locked():
            return False

        return self.detector.detect(data)
