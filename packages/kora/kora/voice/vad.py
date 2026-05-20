# =============================================================================
# Kora Voice — VAD (Voice Activity Detection)
# =============================================================================
# Detecta fala/silêncio usando energia RMS do áudio.
# Grava enquanto houver fala, para após SILENCE_SECONDS de silêncio.
# Tempo máximo de segurança: MAX_RECORD_SECONDS.
# =============================================================================

import logging
import struct
import math
import time
import wave
from pathlib import Path

try:
    import webrtcvad
    WEBRTCVAD_AVAILABLE = True
except ImportError:
    WEBRTCVAD_AVAILABLE = False
    webrtcvad = None

logger = logging.getLogger("kora.voice.vad")

# ── Configuration ────────────────────────────────────────────────────────────

import os

SILENCE_SECONDS = float(os.environ.get("KORA_VAD_SILENCE", "1.8"))       # Seconds of silence before stopping
MAX_RECORD_SECONDS = float(os.environ.get("KORA_VAD_MAX_DURATION", "20.0"))   # Safety cap
MIN_SPEECH_SECONDS = float(os.environ.get("KORA_VAD_MIN_SPEECH", "0.5"))    # Minimum speech before we accept silence
RMS_THRESHOLD = int(os.environ.get("KORA_VAD_THRESHOLD", "150"))          # RMS threshold for "speech" (adjust per mic)
NOISE_SUPPRESSION_AGGRESSIVENESS = int(os.environ.get("KORA_VAD_AGGRESSIVENESS", "2"))  # 0=quality, 1=normal, 2=aggressive, 3=very aggressive
SAMPLE_RATE = 16000
CHANNELS = 1
SAMPLE_WIDTH = 2             # 16-bit PCM → 2 bytes

# Chunk size: 20ms at 16kHz = 320 samples (required by webrtcvad)
CHUNK_SAMPLES = 320
CHUNK_BYTES = CHUNK_SAMPLES * SAMPLE_WIDTH


def _rms(data: bytes) -> float:
    """Calculate RMS energy of 16-bit PCM audio data."""
    if len(data) < 2:
        return 0.0
    count = len(data) // 2
    try:
        samples = struct.unpack(f"<{count}h", data[:count * 2])
        sum_sq = sum(s * s for s in samples)
        return math.sqrt(sum_sq / count)
    except Exception:
        return 0.0


def _is_speech(data: bytes, rms_threshold: float = RMS_THRESHOLD) -> bool:
    """Detect speech using webrtcvad if available, otherwise fallback to RMS threshold."""
    if WEBRTCVAD_AVAILABLE:
        try:
            vad = webrtcvad.VAD(NOISE_SUPPRESSION_AGGRESSIVENESS)
            is_speech = vad.is_speech(data, SAMPLE_RATE)
            return is_speech
        except Exception as e:
            logger.debug(f"webrtcvad detection failed: {e}, falling back to RMS")
    # Fallback to RMS-based detection
    rms = _rms(data)
    return rms >= rms_threshold


def record_with_vad(
    output_path: Path,
    silence_seconds: float = SILENCE_SECONDS,
    max_seconds: float = MAX_RECORD_SECONDS,
    min_speech_seconds: float = MIN_SPEECH_SECONDS,
    rms_threshold: float = RMS_THRESHOLD,
) -> tuple[Path, float]:
    """
    Record audio until speech + silence pattern detected.
    Uses webrtcvad for robust speech detection if available, otherwise falls back to RMS.

    Returns (path, duration_seconds).
    Raises RuntimeError if audio can't be opened.
    """
    import pyaudio

    audio = pyaudio.PyAudio()

    try:
        stream = audio.open(
            format=pyaudio.paInt16,
            channels=CHANNELS,
            rate=SAMPLE_RATE,
            input=True,
            frames_per_buffer=CHUNK_SAMPLES,
        )
    except Exception as e:
        audio.terminate()
        raise RuntimeError(f"Não foi possível abrir microfone: {e}") from e

    frames = []
    started_speech = False
    speech_start = 0.0
    silence_start = 0.0
    total_start = time.monotonic()
    vad_method = "webrtcvad" if WEBRTCVAD_AVAILABLE else "RMS threshold"
    logger.debug(f"VAD: usando método de detecção: {vad_method}")

    try:
        while True:
            elapsed = time.monotonic() - total_start
            if elapsed >= max_seconds:
                logger.info(f"VAD: tempo máximo atingido ({max_seconds}s)")
                break

            data = stream.read(CHUNK_SAMPLES, exception_on_overflow=False)
            frames.append(data)

            # Use enhanced speech detection with webrtcvad
            is_voice = _is_speech(data, rms_threshold)

            if is_voice:
                # Speech detected
                if not started_speech:
                    started_speech = True
                    speech_start = time.monotonic()
                    logger.debug("VAD: fala detectada")
                silence_start = 0.0  # reset silence counter
            else:
                # Silence
                if started_speech:
                    speech_duration = time.monotonic() - speech_start
                    if speech_duration >= min_speech_seconds:
                        if silence_start == 0.0:
                            silence_start = time.monotonic()
                        silence_elapsed = time.monotonic() - silence_start
                        if silence_elapsed >= silence_seconds:
                            logger.info(
                                f"VAD: silêncio detectado por {silence_seconds}s "
                                f"após {speech_duration:.1f}s de fala (método: {vad_method})"
                            )
                            break
    finally:
        stream.stop_stream()
        stream.close()
        audio.terminate()

    # Write WAV
    duration = time.monotonic() - total_start
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(output_path), "wb") as wf:
        wf.setnchannels(CHANNELS)
        wf.setsampwidth(SAMPLE_WIDTH)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(b"".join(frames))

    logger.info(f"VAD: gravou {duration:.1f}s → {output_path} (método: {vad_method})")
    return output_path, duration


def cmd_test() -> None:
    """Interactive VAD test from CLI."""
    from .config import KORA_VOICE_TMP_DIR, ensure_voice_dirs
    ensure_voice_dirs()

    print("\n  🎙 Teste de VAD (Voice Activity Detection)")
    print(f"  Threshold RMS: {RMS_THRESHOLD}")
    print(f"  Silêncio para parar: {SILENCE_SECONDS}s")
    print(f"  Tempo máximo: {MAX_RECORD_SECONDS}s")
    print(f"  Fala mínima: {MIN_SPEECH_SECONDS}s")
    print()
    print("  Fale agora...")

    output = KORA_VOICE_TMP_DIR / "vad_test.wav"
    try:
        path, duration = record_with_vad(output)
        print(f"\n  ✓ Gravação encerrada após {duration:.1f}s")
        print(f"  ✓ Arquivo: {path}")
        print(f"  ✓ Tamanho: {path.stat().st_size / 1024:.1f} KB")
    except RuntimeError as e:
        print(f"\n  ✗ Erro: {e}")
    except KeyboardInterrupt:
        print("\n  [Cancelado]")
