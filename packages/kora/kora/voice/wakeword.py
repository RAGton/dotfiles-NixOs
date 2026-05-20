# =============================================================================
# Kora Voice — Wake-word Detection
# =============================================================================

import logging
import numpy as np
try:
    from scipy import signal
    SCIPY_AVAILABLE = True
except ImportError:
    SCIPY_AVAILABLE = False

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

def _resample_to_16khz(audio_data: bytes, input_rate: int) -> bytes:
    """Resample audio data to 16kHz if needed.

    Args:
        audio_data: Raw 16-bit PCM audio bytes
        input_rate: Sample rate of input audio (Hz)

    Returns:
        Resampled audio as bytes (always 16kHz)
    """
    if input_rate == 16000:
        return audio_data

    if not SCIPY_AVAILABLE:
        logger.warning(f"scipy not available, cannot resample from {input_rate}Hz to 16kHz. Using as-is.")
        return audio_data

    try:
        # Convert bytes to numpy array (16-bit signed integers)
        audio_np = np.frombuffer(audio_data, dtype=np.int16)

        # Compute resampling ratio
        ratio = 16000 / input_rate
        num_samples = int(len(audio_np) * ratio)

        # Use scipy's resample_poly for high-quality resampling
        if SCIPY_AVAILABLE:
            from scipy.signal import resample_poly
            # Find simple ratios for integer resampling when possible
            gcd_val = np.gcd(16000, input_rate)
            up = 16000 // gcd_val
            down = input_rate // gcd_val

            if up < 100 and down < 100:  # Only use polyphase if ratios are reasonable
                resampled = resample_poly(audio_np, up, down)
            else:
                # Fallback to linear interpolation
                resampled = signal.resample(audio_np, num_samples)
        else:
            # Fallback: simple linear interpolation if scipy unavailable
            indices = np.linspace(0, len(audio_np) - 1, num_samples)
            resampled = np.interp(indices, np.arange(len(audio_np)), audio_np)

        # Convert back to 16-bit signed integers
        resampled = np.clip(resampled, -32768, 32767).astype(np.int16)
        return resampled.tobytes()
    except Exception as e:
        logger.error(f"Error resampling audio from {input_rate}Hz to 16kHz: {e}")
        return audio_data


class KoraWakeWord:
    def __init__(self, model="kora"):
        self.model_name = model
        self.active = False
        self.oww_model = None
        self.ready = False
        self.input_rate = 16000  # Will be updated if needed

        if OPENWAKEWORD_AVAILABLE:
            try:
                # Try to use 'kora' model first.
                self.oww_model = Model(wakeword_models=[self.model_name])
                loaded = list(getattr(self.oww_model, 'models', {}).keys()) or [self.model_name]
                logger.info(f"Wake-word engine initialized (models: {loaded})")
                self.ready = True
            except TypeError:
                # openWakeWord 0.5.x changed the constructor signature
                try:
                    self.oww_model = Model(model_names=[self.model_name])
                    loaded = list(getattr(self.oww_model, 'models', {}).keys()) or [self.model_name]
                    logger.info(f"Wake-word engine initialized via model_names (models: {loaded})")
                    self.ready = True
                except Exception as e:
                    logger.warning(f"Failed to initialize openWakeWord Model '{self.model_name}': {e}. Falling back to 'hey_mycroft'.")
                    try:
                        self.model_name = "hey_mycroft"
                        self.oww_model = Model(model_names=["hey_mycroft"])
                        logger.info("Wake-word engine initialized with fallback (models: ['hey_mycroft'])")
                        self.ready = True
                    except Exception as ex:
                        logger.error(f"Fallback also failed: {ex}")
                        logger.info("Wake-word engine falling back to foundation mode (no model found).")
            except Exception as e:
                logger.warning(f"Failed to initialize openWakeWord Model '{self.model_name}': {e}. Falling back to 'hey_mycroft'.")
                try:
                    self.model_name = "hey_mycroft"
                    self.oww_model = Model(wakeword_models=["hey_mycroft"])
                    logger.info("Wake-word engine initialized with fallback (models: ['hey_mycroft'])")
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
        Automatically resamples to 16kHz if input is in different sample rate.
        Returns True if detected.
        """
        if not self.ready or not self.active or not self.oww_model:
            return False

        try:
            # Resample to 16kHz if needed (ensures robustness against frame rate divergence)
            audio_data = _resample_to_16khz(audio_data, self.input_rate)

            # Convert bytes to numpy array
            audio_np = np.frombuffer(audio_data, dtype=np.int16)

            # Prediction returns a dict of scores
            prediction = self.oww_model.predict(audio_np)

            for mdl, score in prediction.items():
                if score > 0.75:
                    logger.info(f"Wake-word detected: {mdl} (score: {score:.2f})")
                    return True
        except Exception as e:
            logger.error(f"Error during wake-word detection: {e}")

        return False

def _try_load_model(model_name: str):
    """Try both constructor signatures and return the Model or raise."""
    try:
        return Model(wakeword_models=[model_name])
    except TypeError:
        return Model(model_names=[model_name])


def get_wakeword_status():
    custom_model_present = False
    active_model = "kora"
    if OPENWAKEWORD_AVAILABLE:
        try:
            temp_model = _try_load_model("kora")
            loaded = getattr(temp_model, 'models', {})
            custom_model_present = "kora" in loaded
        except:
            try:
                _try_load_model("hey_mycroft")
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
        self.device_index = None
        self._last_open_attempt: float = 0.0
        self._open_backoff: float = 2.0  # seconds between failed open attempts

        # Audio configuration
        self.chunk_size = 1280      # ~80ms at 16kHz (baseline)
        self.active_chunk_size = self.chunk_size  # adjusted per actual capture rate
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

    def _find_named_default_index(self) -> int | None:
        """Return the index of the device whose ALSA name is exactly 'default'."""
        if self.pyaudio is None:
            return None
        try:
            count = self.pyaudio.get_device_count()
        except Exception:
            return None
        for i in range(count if isinstance(count, int) else 0):
            try:
                info = self.pyaudio.get_device_info_by_index(i)
            except Exception:
                continue
            if not isinstance(info, dict) or info.get("maxInputChannels", 0) < 1:
                continue
            if str(info.get("name", "")).lower() == "default":
                return i
        return None

    def _find_input_device_index(self) -> int | None:
        """Return the index of the best available input device.

        Priority (strict):
          1. Bluetooth device — name contains "bluez" or "jbl"
          2. PipeWire/PulseAudio soft-mix — name contains "default", "pipewire" or "pulse"
          3. None → PyAudio picks its own default
        """
        if self.pyaudio is None:
            return None

        try:
            device_count = self.pyaudio.get_device_count()
            if not isinstance(device_count, int):
                device_count = 0
        except Exception:
            device_count = 0

        bt_index: int | None = None
        fallback_index: int | None = None

        for i in range(device_count):
            try:
                info = self.pyaudio.get_device_info_by_index(i)
            except Exception:
                continue
            if not isinstance(info, dict):
                continue
            channels = info.get("maxInputChannels", 0)
            if not isinstance(channels, int) or channels < 1:
                continue
            name = str(info.get("name", "")).lower()
            if bt_index is None and ("bluez" in name or "jbl" in name):
                bt_index = i
                logger.info("WakeWordEngine: found BT device #%d '%s'", i, info.get("name", ""))
            elif fallback_index is None and ("default" in name or "pipewire" in name or "pulse" in name):
                fallback_index = i

        chosen = bt_index if bt_index is not None else fallback_index
        if chosen is not None:
            logger.debug("WakeWordEngine: selected device #%d (bt=%s)", chosen, bt_index is not None)
        return chosen

    def _get_device_native_rate(self, device_idx: int | None) -> int:
        """Return the device's defaultSampleRate from PortAudio info (fallback: 48000)."""
        if self.pyaudio is None:
            return 48000
        if device_idx is None:
            return 48000  # BT/PipeWire virtual devices typically run at 48kHz
        try:
            info = self.pyaudio.get_device_info_by_index(device_idx)
            rate = int(info.get("defaultSampleRate", 48000))
            return rate if rate > 0 else 48000
        except Exception:
            return 48000

    def _try_open(self, device_idx: int | None, rate: int) -> bool:
        """Open an input stream at *rate* Hz. Sets active_stream + active_chunk_size on success."""
        chunk = max(512, int(rate * 0.08))  # ~80ms buffer at given rate
        with _suppress_alsa_stderr():
            stream = self.pyaudio.open(
                format=self.format,
                channels=self.channels,
                rate=rate,
                input=True,
                frames_per_buffer=chunk,
                input_device_index=device_idx,
            )
        self.active_stream = stream
        self.active_chunk_size = chunk
        self.detector.input_rate = rate
        logger.info(
            "WakeWordEngine: stream opened — device=%s  capture=%dHz  detect=16kHz%s",
            device_idx if device_idx is not None else "portaudio-default",
            rate,
            "  [resampling active]" if rate != 16000 else "",
        )
        self._open_backoff = 2.0
        return True

    def start_stream(self) -> bool:
        if self.active_stream is not None:
            return True

        now = time.monotonic()
        if now - self._last_open_attempt < self._open_backoff:
            return False
        self._last_open_attempt = now

        self._init_pyaudio()
        self.device_index = self._find_input_device_index()
        default_idx = self._find_named_default_index()

        # Deduplicated candidate list: BT/best → ALSA "default" → PortAudio None
        seen: set = set()
        candidates: list[int | None] = []
        for dev in (self.device_index, default_idx, None):
            key = dev if dev is not None else -1
            if key not in seen:
                seen.add(key)
                candidates.append(dev)

        for dev in candidates:
            native = self._get_device_native_rate(dev)
            # Try 16kHz first (no resampling overhead); fall back to native rate
            rates = [16000, native] if native != 16000 else [16000]
            for rate in rates:
                try:
                    return self._try_open(dev, rate)
                except Exception as e:
                    logger.warning(
                        "WakeWordEngine: open failed (device=%s rate=%dHz): %s",
                        dev if dev is not None else "portaudio-default",
                        rate, e,
                    )

        logger.error("WakeWordEngine: all open attempts exhausted")
        self._open_backoff = min(self._open_backoff * 2, 30.0)
        return False

    def close_stream(self) -> None:
        stream = self.active_stream
        self.active_stream = None  # clear before any call to prevent re-entry
        if stream is None:
            return
        try:
            if stream.is_active():
                stream.stop_stream()
        except Exception:
            pass
        try:
            stream.close()
        except OSError:
            pass
        except Exception as e:
            logger.warning("WakeWordEngine: Error closing stream: %s", e)
        logger.info("WakeWordEngine: PyAudio stream closed.")

    def shutdown(self) -> None:
        """Stop stream and terminate PyAudio. Must be called before object is freed."""
        self.close_stream()
        if self.pyaudio is not None:
            try:
                self.pyaudio.terminate()
            except Exception as e:
                logger.warning("WakeWordEngine: Error terminating PyAudio: %s", e)
            finally:
                self.pyaudio = None

    def __del__(self) -> None:
        try:
            self.shutdown()
        except Exception:
            pass

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
            data = self.active_stream.read(self.active_chunk_size, exception_on_overflow=False)
            if self.detector.detect(data):
                return True
        except Exception as e:
            logger.error(f"WakeWordEngine: Error reading chunk: {e}")
            self.stream.close()

        return False

