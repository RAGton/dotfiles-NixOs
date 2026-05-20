import os
import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch
import numpy as np
import pytest

from kora.voice.stt import transcribe_audio
from kora.voice.tts import synthesize_text
from kora.voice.pipeline import run_voice_pipeline


@pytest.fixture(autouse=True)
def clean_whisper_singleton():
    """Clear Whisper singleton before and after each test."""
    with patch("kora.voice.stt._whisper_model_instance", None):
        yield


def test_transcribe_audio_file_input():
    mock_model = MagicMock()
    mock_model.transcribe.return_value = (
        [MagicMock(text="Olá, isso é um teste.")],
        MagicMock()
    )

    with patch("faster_whisper.WhisperModel", return_value=mock_model):
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            temp_path = Path(f.name)
        try:
            # Test path input
            res = transcribe_audio(temp_path)
            assert "um teste" in res.lower()
            mock_model.transcribe.assert_called_once()
        finally:
            if temp_path.exists():
                os.unlink(temp_path)


def test_transcribe_audio_bytes_input():
    mock_model = MagicMock()
    mock_model.transcribe.return_value = (
        [MagicMock(text="Transcrição de bytes.")],
        MagicMock()
    )

    with patch("faster_whisper.WhisperModel", return_value=mock_model):
        dummy_pcm_bytes = b"\x00" * 32000  # 1 second of 16kHz audio
        res = transcribe_audio(dummy_pcm_bytes)
        assert "bytes" in res.lower()
        mock_model.transcribe.assert_called_once()


def test_transcribe_audio_numpy_input():
    mock_model = MagicMock()
    mock_model.transcribe.return_value = (
        [MagicMock(text="Transcrição de array.")],
        MagicMock()
    )

    with patch("faster_whisper.WhisperModel", return_value=mock_model):
        dummy_array = np.zeros(16000, dtype=np.float32)
        res = transcribe_audio(dummy_array)
        assert "array" in res.lower()
        mock_model.transcribe.assert_called_once()


def test_synthesize_text():
    import wave

    async def _fake_synthesize(text: str, out_wav) -> None:
        with wave.open(str(out_wav), "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(22050)
            wf.writeframes(b"\x00" * 4410)

    mock_provider = MagicMock()
    mock_provider.synthesize = _fake_synthesize

    with patch("kora.voice.providers.build_provider_chain", return_value=mock_provider), \
         patch("kora.voice.tts.shutil.which", return_value="/usr/bin/ffplay"), \
         patch("kora.voice.tts.subprocess.run") as mock_run:

        synthesize_text("Olá")

        mock_run.assert_called_once()
        args = mock_run.call_args[0][0]
        assert "ffplay" in args[0]


def test_run_voice_pipeline():
    import asyncio
    # Setup mocks for one loop iteration
    mock_engine = MagicMock()
    # First call returns True, second raises KeyboardInterrupt to exit loop
    mock_engine.listen.side_effect = [True, KeyboardInterrupt()]
    
    mock_recorder = MagicMock()
    mock_recorder.record_to_file.return_value = "/tmp/dummy.wav"

    with patch("kora.voice.wakeword.WakeWordEngine", return_value=mock_engine), \
         patch("kora.voice.pipeline.KoraRecorder", return_value=mock_recorder), \
         patch("kora.voice.pipeline.transcribe_audio", return_value="Executar atualização do sistema") as mock_transcribe, \
         patch("kora.voice.pipeline.process_message", return_value={"answer": "Atualizando agora.", "elapsed_sec": 0.5, "mode": "mock"}) as mock_process, \
         patch("kora.voice.tts.synthesize_text") as mock_synthesize, \
         patch("kora.utils.lock.HardwareLock") as mock_lock:
        
        asyncio.run(run_voice_pipeline())
        
        # Verify transcription was called
        mock_transcribe.assert_called_once_with("/tmp/dummy.wav", user="rocha")
        # Verify orchestrator process_message was called
        mock_process.assert_called_once()
        # Verify transcribe_audio was called with the reply
        mock_synthesize.assert_called_once_with("Atualizando agora.")


def test_is_voice_enabled_mute_file():
    from kora.voice.pipeline import is_voice_enabled
    
    # Test when mute file exists
    with patch("kora.voice.pipeline.Path.exists", return_value=True):
        assert is_voice_enabled() is False

    # Test when mute file does not exist, fallback to environment
    with patch("kora.voice.pipeline.Path.exists", return_value=False), \
         patch.dict(os.environ, {"KORA_VOICE_ENABLED": "false"}):
        assert is_voice_enabled() is False

    # Test when mute file does not exist, and env is true
    with patch("kora.voice.pipeline.Path.exists", return_value=False), \
         patch.dict(os.environ, {"KORA_VOICE_ENABLED": "true"}):
        assert is_voice_enabled() is True
