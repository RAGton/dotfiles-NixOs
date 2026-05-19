# =============================================================================
# Kora Voice — Wake-word Detection
# =============================================================================

import logging
import numpy as np

try:
    from openwakeword.model import Model
    OPENWAKEWORD_AVAILABLE = True
except ImportError:
    try:
        from pyopen_wakeword import Model
        OPENWAKEWORD_AVAILABLE = True
    except ImportError:
        OPENWAKEWORD_AVAILABLE = False

logger = logging.getLogger("kora.voice.wakeword")

class KoraWakeWord:
    def __init__(self, model="kora"):
        self.model_name = model
        self.active = False
        self.oww_model = None
        self.ready = False

        if OPENWAKEWORD_AVAILABLE:
            try:
                # Try to use 'kora' model first.
                self.oww_model = Model(wakeword_models=[self.model_name])
                logger.info(f"Wake-word engine initialized (models: {self.oww_model.wakeword_models})")
                self.ready = True
            except Exception as e:
                logger.warning(f"Failed to initialize openWakeWord Model '{self.model_name}': {e}. Falling back to 'hey_mycroft'.")
                try:
                    self.model_name = "hey_mycroft"
                    self.oww_model = Model(wakeword_models=["hey_mycroft"])
                    logger.info(f"Wake-word engine initialized with fallback (models: {self.oww_model.wakeword_models})")
                    self.ready = True
                except Exception as ex:
                    logger.error(f"Fallback also failed: {ex}")
                    logger.info("Wake-word engine falling back to foundation mode (no model found).")
        else:
            logger.warning("openWakeWord library not available. Using foundation stub.")

    def start(self):
        self.active = True
        logger.info("Wake-word detection enabled.")

    def stop(self):
        self.active = False
        logger.info("Wake-word detection disabled.")

    def detect(self, audio_data: bytes) -> bool:
        """
        Detect wake-word in audio data (expecting 16kHz mono 16-bit PCM).
        Returns True if detected.
        """
        if not self.ready or not self.active or not self.oww_model:
            return False

        try:
            # Convert bytes to numpy array
            audio_np = np.frombuffer(audio_data, dtype=np.int16)

            # Prediction returns a dict of scores
            prediction = self.oww_model.predict(audio_np)

            for mdl, score in prediction.items():
                if score > 0.5:
                    logger.info(f"Wake-word detected: {mdl} (score: {score:.2f})")
                    return True
        except Exception as e:
            logger.error(f"Error during wake-word detection: {e}")

        return False

def get_wakeword_status():
    custom_model_present = False
    active_model = "kora"
    if OPENWAKEWORD_AVAILABLE:
        try:
            temp_model = Model(wakeword_models=["kora"])
            custom_model_present = "kora" in temp_model.wakeword_models
        except:
            try:
                temp_model = Model(wakeword_models=["hey_mycroft"])
                custom_model_present = True
                active_model = "hey_mycroft"
            except:
                custom_model_present = False

    return {
        "target_wake_word": active_model,
        "backend": "openWakeWord" if OPENWAKEWORD_AVAILABLE else "foundation (missing lib)",
        "custom_kora_model": "present" if (custom_model_present and active_model == "kora") else ("fallback" if custom_model_present else "missing"),
        "status": "validated" if custom_model_present else "foundation",
        "ready": OPENWAKEWORD_AVAILABLE and custom_model_present,
        "note": "Wake-word configurado como alvo. Usando fallback se kora não for encontrado."
    }


import contextlib
import os
import time
import pyaudio
from pathlib import Path


@contextlib.contextmanager
def _suppress_alsa_stderr():
    """Redirect C-level stderr to /dev/null during PortAudio device probe.

    PortAudio's ALSA host API prints Expression-failed messages straight to
    file-descriptor 2 when probing hardware devices locked by PipeWire.
    Python-level sys.stderr redirection does not catch these; we need to
    temporarily replace the fd itself.
    """
    devnull_fd = os.open(os.devnull, os.O_WRONLY)
    saved_fd = os.dup(2)
    try:
        os.dup2(devnull_fd, 2)
        yield
    finally:
        os.dup2(saved_fd, 2)
        os.close(saved_fd)
        os.close(devnull_fd)


class PyAudioStreamWrapper:
    """Wrapper that exposes start() and close() methods to match constraints."""
    def __init__(self, engine: "WakeWordEngine") -> None:
        self.engine = engine

    def start(self) -> bool:
        return self.engine.start_stream()

    def close(self) -> None:
        self.engine.close_stream()


class WakeWordEngine:
    """
    Wake-word engine that reads from PyAudio and handles hardware lock checks.
    """
    def __init__(self, model: str = "kora") -> None:
        self.detector = KoraWakeWord(model)
        self.detector.start()
        self.lock_path = Path(f"/run/user/{os.getuid()}/kryonix/voice.lock")
        self.pyaudio = None
        self.active_stream = None
        self.stream = PyAudioStreamWrapper(self)
        self._last_open_attempt: float = 0.0
        self._open_backoff: float = 2.0  # seconds between failed open attempts

        # Audio configuration
        self.chunk_size = 1280  # ~80ms at 16kHz
        self.rate = 16000
        self.channels = 1
        self.format = pyaudio.paInt16

    def is_locked(self) -> bool:
        return self.lock_path.exists()

    def _init_pyaudio(self) -> None:
        """Initialise PyAudio, silencing PortAudio's ALSA probe noise."""
        if self.pyaudio is not None:
            return
        with _suppress_alsa_stderr():
            self.pyaudio = pyaudio.PyAudio()

    def _find_input_device_index(self) -> int | None:
        """Return the index of the best available soft-mix input device.

        Priority: PipeWire virtual device > PulseAudio compat device > None.
        Returning None lets PyAudio fall back to its own default selection.
        """
        if self.pyaudio is None:
            return None
        for i in range(self.pyaudio.get_device_count()):
            try:
                info = self.pyaudio.get_device_info_by_index(i)
            except Exception:
                continue
            if info.get("maxInputChannels", 0) < 1:
                continue
            name = info.get("name", "").lower()
            if "pipewire" in name or "pulse" in name:
                logger.debug("WakeWordEngine: using soft-mix device #%d '%s'", i, info["name"])
                return i
        return None

    def start_stream(self) -> bool:
        if self.active_stream is not None:
            return True

        now = time.monotonic()
        if now - self._last_open_attempt < self._open_backoff:
            return False
        self._last_open_attempt = now

        self._init_pyaudio()
        device_index = self._find_input_device_index()

        try:
            with _suppress_alsa_stderr():
                self.active_stream = self.pyaudio.open(
                    format=self.format,
                    channels=self.channels,
                    rate=self.rate,
                    input=True,
                    frames_per_buffer=self.chunk_size,
                    input_device_index=device_index,
                )
            logger.info(
                "WakeWordEngine: stream opened (device=%s)",
                device_index if device_index is not None else "default",
            )
            self._open_backoff = 2.0  # reset on success
            return True
        except Exception as e:
            logger.warning("WakeWordEngine: failed to open stream (device=%s): %s", device_index, e)
            self.active_stream = None
            self._open_backoff = min(self._open_backoff * 2, 30.0)  # exponential backoff, max 30s
            return False

    def close_stream(self) -> None:
        if self.active_stream is not None:
            try:
                self.active_stream.stop_stream()
                self.active_stream.close()
            except Exception as e:
                logger.warning(f"WakeWordEngine: Error closing stream: {e}")
            finally:
                self.active_stream = None
                logger.info("WakeWordEngine: PyAudio stream closed.")

    def listen(self) -> bool:
        """
        Periodically check lock file.
        If file exists, call stream.close() if stream is open.
        If it does not exist, call stream.start().
        Processes PyAudio chunks and returns True if 'Kora' is detected.
        """
        if self.is_locked():
            if self.active_stream is not None:
                self.stream.close()
            return False

        if self.active_stream is None:
            success = self.stream.start()
            if not success:
                return False

        try:
            data = self.active_stream.read(self.chunk_size, exception_on_overflow=False)
            if self.detector.detect(data):
                return True
        except Exception as e:
            logger.error(f"WakeWordEngine: Error reading chunk: {e}")
            self.stream.close()

        return False

