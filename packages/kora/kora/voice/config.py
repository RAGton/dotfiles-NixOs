# =============================================================================
# Kora Voice — Configuration
# =============================================================================

import os
from pathlib import Path

# Backends
KORA_VOICE_STT_BACKEND = os.environ.get("KORA_VOICE_STT_BACKEND", "whisper_cpp")
KORA_VOICE_TTS_BACKEND = os.environ.get("KORA_VOICE_TTS_BACKEND", "piper")

# Directories
KORA_VOICE_TMP_DIR  = Path("/tmp/kora-voice")
KORA_VOICE_DATA_DIR = Path("/var/lib/kryonix/kora/voice")
KORA_MODELS_DIR     = KORA_VOICE_DATA_DIR / "models"

# ---------------------------------------------------------------------------
# Whisper model — resolved at import time so callers don't need to import models
# Order: env var → current.bin symlink → ggml-base.bin fallback
# ---------------------------------------------------------------------------
def _resolve_whisper_model() -> str:
    env = os.environ.get("KORA_WHISPER_MODEL")
    if env and Path(env).exists():
        return env
    for candidate in [
        KORA_MODELS_DIR / "whisper" / "current.bin",
        KORA_MODELS_DIR / "whisper" / "ggml-base.bin",
        # legacy path (pre-models-manager)
        Path("/var/lib/kryonix/kora/models/whisper-base.bin"),
    ]:
        if candidate.exists() and candidate.stat().st_size > 1_000_000:
            return str(candidate)
    # Return a descriptive path so the error message is meaningful
    return str(KORA_MODELS_DIR / "whisper" / "ggml-base.bin")

# ---------------------------------------------------------------------------
# Piper model — resolved at import time
# Order: env var → current.onnx symlink → faber → cadu
# ---------------------------------------------------------------------------
def _resolve_piper_model() -> str:
    env = os.environ.get("KORA_PIPER_MODEL")
    if env and Path(env).exists():
        return env
    for candidate in [
        KORA_MODELS_DIR / "piper" / "current.onnx",
        KORA_MODELS_DIR / "piper" / "pt_BR-edresson-low.onnx",
        KORA_MODELS_DIR / "piper" / "pt_BR-faber-medium.onnx",
        KORA_MODELS_DIR / "piper" / "pt_BR-cadu-medium.onnx",
        Path("/var/lib/kryonix/kora/models/piper-pt_BR.onnx"),
    ]:
        if candidate.exists() and candidate.stat().st_size > 1_000:
            return str(candidate)
    return str(KORA_MODELS_DIR / "piper" / "pt_BR-edresson-low.onnx")

def _resolve_piper_config() -> str:
    env = os.environ.get("KORA_PIPER_CONFIG")
    if env and Path(env).exists():
        return env
    for candidate in [
        KORA_MODELS_DIR / "piper" / "current.onnx.json",
        KORA_MODELS_DIR / "piper" / "pt_BR-edresson-low.onnx.json",
        KORA_MODELS_DIR / "piper" / "pt_BR-faber-medium.onnx.json",
        KORA_MODELS_DIR / "piper" / "pt_BR-cadu-medium.onnx.json",
        Path("/var/lib/kryonix/kora/models/piper-pt_BR.onnx.json"),
    ]:
        if candidate.exists():
            return str(candidate)
    return str(KORA_MODELS_DIR / "piper" / "pt_BR-edresson-low.onnx.json")

WHISPER_MODEL_PATH = _resolve_whisper_model()
PIPER_MODEL_PATH   = _resolve_piper_model()
PIPER_CONFIG_PATH  = _resolve_piper_config()

# ---------------------------------------------------------------------------
# SFX Audio Cues (Phase 3)
# ---------------------------------------------------------------------------
KORA_SFX_DIR = KORA_VOICE_DATA_DIR / "sfx"
SFX_ACTIVATION = KORA_SFX_DIR / "activation.wav"
SFX_THINKING   = KORA_SFX_DIR / "thinking.wav"
SFX_ERROR      = KORA_SFX_DIR / "error.wav"

# Safety & Privacy
KORA_VOICE_SAVE_AUDIO = os.environ.get("KORA_VOICE_SAVE_AUDIO", "0") == "1"
KORA_VOICE_REQUIRE_CONSENT_FOR_VOICEPRINT = True

def ensure_voice_dirs():
    """Ensure runtime and data directories exist."""
    KORA_VOICE_TMP_DIR.mkdir(parents=True, exist_ok=True)
    KORA_VOICE_DATA_DIR.mkdir(parents=True, exist_ok=True)
    (KORA_VOICE_DATA_DIR / "profiles").mkdir(parents=True, exist_ok=True)
    (KORA_VOICE_DATA_DIR / "archive").mkdir(parents=True, exist_ok=True)
    (KORA_MODELS_DIR / "whisper").mkdir(parents=True, exist_ok=True)
    (KORA_MODELS_DIR / "piper").mkdir(parents=True, exist_ok=True)
    KORA_SFX_DIR.mkdir(parents=True, exist_ok=True)
