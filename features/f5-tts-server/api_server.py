#!/usr/bin/env python3
"""
F5-TTS Inference Server — REST API para síntese de voz zero-shot (Kora/glacier).

Endpoints:
  GET  /health      → {"status":"ok","model_loaded":bool}
  POST /synthesize  → audio/wav
"""

import io
import logging
import os
import threading
from pathlib import Path
from typing import Optional

import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("f5tts.server")

app = FastAPI(title="F5-TTS Server", version="1.0.0")

_tts = None
_tts_lock = threading.Lock()
_tts_error: Optional[str] = None


def _load_model() -> None:
    global _tts, _tts_error
    with _tts_lock:
        if _tts is not None:
            return
        logger.info("Carregando F5-TTS base model na GPU...")
        try:
            from f5_tts.api import F5TTS  # type: ignore[import]
            _tts = F5TTS()
            logger.info("Modelo F5-TTS carregado com sucesso")
        except Exception as exc:
            _tts_error = str(exc)
            logger.error("Falha ao carregar modelo: %s", exc)


def _get_tts():
    if _tts is None:
        _load_model()
    if _tts is None:
        raise RuntimeError(f"Modelo não disponível: {_tts_error}")
    return _tts


# Pré-aquece o modelo em background ao iniciar o servidor
threading.Thread(target=_load_model, daemon=True, name="f5tts-warmup").start()


# ─── Schemas ──────────────────────────────────────────────────────────────────

class SynthesizeRequest(BaseModel):
    text: str
    ref_audio: str = "/var/lib/f5-tts/voices/kora.wav"
    ref_text: str = ""


# ─── Endpoints ───────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    return {
        "status": "ok",
        "model_loaded": _tts is not None,
        "model_error": _tts_error,
    }


@app.post("/synthesize")
async def synthesize(req: SynthesizeRequest) -> Response:
    text = req.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="text is empty")

    ref_audio = Path(req.ref_audio)
    if not ref_audio.exists():
        raise HTTPException(
            status_code=404,
            detail=f"ref_audio não encontrado: {req.ref_audio}",
        )

    # ref_text vazio → F5-TTS auto-transcreve (whisper interno, +~2s)
    ref_text = req.ref_text

    # Se kora.txt existir ao lado de kora.wav, usa como ref_text automático
    if not ref_text:
        txt_path = ref_audio.with_suffix(".txt")
        if txt_path.exists():
            ref_text = txt_path.read_text(encoding="utf-8").strip()
            logger.debug("ref_text carregado de %s", txt_path)

    tts = _get_tts()

    try:
        logger.info("Sintetizando: %r (ref=%s)", text[:60], ref_audio.name)
        result = tts.infer(
            ref_file=str(ref_audio),
            ref_text=ref_text,
            gen_text=text,
        )
        wav, sr = result[0], result[1]

        import soundfile as sf  # type: ignore[import]

        buf = io.BytesIO()
        sf.write(buf, wav, sr, format="WAV", subtype="PCM_16")
        buf.seek(0)

        logger.info("Síntese OK — %d bytes", buf.getbuffer().nbytes)
        return Response(content=buf.read(), media_type="audio/wav")

    except Exception as exc:
        logger.exception("Síntese falhou: %r", text[:60])
        raise HTTPException(status_code=500, detail=str(exc)) from exc


# ─── Entry point ─────────────────────────────────────────────────────────────

if __name__ == "__main__":
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=int(os.environ.get("F5TTS_PORT", "7860")),
        log_level="info",
    )
