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


import os
import sys
from pathlib import Path


# Chunk size: 1280 samples × 2 bytes (s16) = 2560 bytes ≈ 80ms at 16kHz.
# pw-record is told to output exactly 16kHz s16 mono raw PCM, so no
# resampling is needed here — the OS/PipeWire does it in the kernel.
_CHUNK_BYTES = 2560


class WakeWordEngine:
    """
    Wake-word engine that reads raw 16kHz s16 mono PCM from stdin.

    Expected invocation (set up by the systemd unit):
        pw-record --channels 1 --rate 16000 --format s16 --raw - \\
            | kora /voice listener

    No PyAudio / PortAudio is used; all hardware interaction lives in
    pw-record, which avoids the GLIBC double-free / SIGABRT bugs that
    plagued the previous PortAudio-under-PipeWire approach.
    """

    def __init__(self, model: str = "kora") -> None:
        self.detector = KoraWakeWord(model)
        self.detector.start()
        self.detector.input_rate = 16000
        self.lock_path = Path(f"/run/user/{os.getuid()}/kryonix/voice.lock")
        logger.info("WakeWordEngine: stdin mode active (pw-record → pipe → kora)")

    def is_locked(self) -> bool:
        return self.lock_path.exists()

    def listen(self) -> bool:
        """Read one chunk from stdin and run wake-word detection.

        When the lock file is present (another process owns the mic), the
        chunk is drained silently to prevent the pipe buffer from filling up
        and stalling pw-record.  Returns True only on a real detection.
        """
        try:
            data = sys.stdin.buffer.read(_CHUNK_BYTES)
        except Exception as e:
            logger.error("WakeWordEngine: stdin read error: %s", e)
            return False

        if not data:
            logger.warning("WakeWordEngine: stdin EOF — pw-record may have exited")
            return False

        if self.is_locked():
            return False  # drain done, mic owned by another process

        return self.detector.detect(data)

