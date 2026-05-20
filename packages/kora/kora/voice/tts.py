# =============================================================================
# Kora Voice — TTS (Text to Speech)
# =============================================================================
# Usa piper-tts (do Nix PATH) com modelo .onnx PT-BR.
# O modelo é resolvido dinamicamente via config.py (current.onnx ou fallback).
# =============================================================================

import shutil
import subprocess
import logging
import os
from pathlib import Path

logger = logging.getLogger("kora.voice.tts")


def preparar_para_voz(texto: str) -> str:
    """
    Normaliza texto para síntese TTS: remove markdown, expande siglas e
    humaniza termos técnicos para que o piper-tts leia naturalmente.
    """
    import re

    # Remove bold / italic (* e **)
    texto = re.sub(r"\*+([^*\n]+)\*+", r"\1", texto)
    # Remove headers markdown (##, ###)
    texto = re.sub(r"^#{1,6}\s+", "", texto, flags=re.MULTILINE)
    # Remove listas com traço ou asterisco no início da linha
    texto = re.sub(r"^[-*]\s+", "", texto, flags=re.MULTILINE)
    # Remove itálico com underscore
    texto = re.sub(r"_([^_\n]+)_", r"\1", texto)
    # Remove blocos de código inline
    texto = re.sub(r"`[^`]+`", lambda m: m.group(0).strip("`"), texto)

    # Expansão de siglas técnicas comuns
    _SIGLAS = [
        ("CPU",    "C P U"),
        ("GPU",    "G P U"),
        ("RAM",    "memória"),
        ("SSD",    "disco"),
        ("HDD",    "disco"),
        ("API",    "A P I"),
        ("SSH",    "S S H"),
        ("URL",    "endereço"),
        ("IP",     "I P"),
        ("NixOS",  "nix O S"),
    ]
    for sigla, expansao in _SIGLAS:
        # Só substitui quando isolada (não parte de palavra maior)
        texto = re.sub(rf"\b{re.escape(sigla)}\b", expansao, texto)

    # Colapsa linhas em branco múltiplas para uma só pausa
    texto = re.sub(r"\n{3,}", "\n\n", texto)

    return texto.strip()


# Binários Piper suportados (injetados via wrapProgram no Nix)
_PIPER_CANDIDATES = [
    "piper-tts",   # nome real do pacote nixpkgs
    "piper",       # alias em alguns empacotamentos
]

def _find_piper_bin() -> str | None:
    for c in _PIPER_CANDIDATES:
        p = shutil.which(c)
        if p:
            return p
    return None


def speak_text(text: str) -> None:
    """Sintetiza texto com Piper usando o preset ativo."""
    synthesize_text(text)


def synthesize_text(text: str) -> None:
    """
    Sintetiza texto usando piper-tts para um arquivo WAV temporário
    e o reproduz usando ffplay ou aplay.
    Aplica parâmetros de qualidade para voz mais natural.
    """
    if not text:
        return
    text = preparar_para_voz(text)

    # Import tardio para evitar ciclo
    from .config import PIPER_MODEL_PATH, PIPER_CONFIG_PATH

    piper_bin = _find_piper_bin()
    if not piper_bin:
        logger.warning("piper-tts não encontrado no PATH — executando fallback spd-say.")
        _fallback_spd_say(text)
        return

    model_path = Path(PIPER_MODEL_PATH)
    if not model_path.exists():
        logger.warning(
            f"Modelo Piper não encontrado em {model_path} — executando fallback spd-say.\n"
            "  → Execute: kora voice models install piper faber"
        )
        _fallback_spd_say(text)
        return

    # Create temporary WAV file
    import tempfile
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        temp_wav_path = f.name

    try:
        # Construct piper-tts command
        piper_cmd = [
            piper_bin,
            "--model", str(model_path),
            "--output_file", temp_wav_path
        ]

        # Config opcional
        config_path = Path(PIPER_CONFIG_PATH)
        if config_path.exists():
            piper_cmd += ["--config", str(config_path)]

        # length_scale: >1 = mais lento/pausado, <1 = mais rápido.
        # 1.1 = ~10% mais lento que o normal — voz natural, sem pressa.
        piper_cmd += ["--length_scale", "1.1"]

        logger.info(f"TTS: Sintetizando com length_scale=1.1 em {temp_wav_path}...")

        # Execute piper-tts writing text to stdin
        piper_proc = subprocess.Popen(
            piper_cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        piper_proc.communicate(input=text.encode("utf-8"))
        piper_proc.wait()

        # Check if the temporary WAV file was written successfully
        if os.path.exists(temp_wav_path) and os.path.getsize(temp_wav_path) > 0:
            ffplay_bin = shutil.which("ffplay")
            aplay_bin = shutil.which("aplay")

            if ffplay_bin:
                logger.info("TTS: Reproduzindo via ffplay...")
                subprocess.run([
                    ffplay_bin,
                    "-nodisp",
                    "-autoexit",
                    "-loglevel", "quiet",
                    temp_wav_path
                ], check=True)
            elif aplay_bin:
                logger.info("TTS: Reproduzindo via aplay...")
                subprocess.run([aplay_bin, temp_wav_path], check=True)
            else:
                logger.warning("Nenhum reprodutor de áudio (ffplay ou aplay) encontrado no PATH.")
        else:
            logger.error("Arquivo temporário WAV não foi gerado pelo piper-tts.")
            _fallback_spd_say(text)

    except Exception as e:
        logger.error(f"Erro em synthesize_text: {e}")
        _fallback_spd_say(text)
    finally:
        try:
            if os.path.exists(temp_wav_path):
                os.unlink(temp_wav_path)
        except Exception as cleanup_err:
            logger.warning(f"Erro ao limpar arquivo de áudio temporário {temp_wav_path}: {cleanup_err}")




def _fallback_spd_say(text: str) -> None:
    """Fallback via spd-say se disponível."""
    spd = shutil.which("spd-say")
    if spd:
        try:
            subprocess.run([spd, text], check=True, timeout=10)
        except Exception:
            pass


def speak_edge_tts(text: str, voice: str) -> bool:
    """Tenta sintetizar texto usando edge-tts e reproduzir com aplay/ffmpeg."""
    try:
        import sys
        import tempfile
        import os
        import subprocess

        with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as f:
            temp_path = f.name
        try:
            # Run edge-tts in a clean subprocess to avoid event loop conflicts in threads
            python_code = (
                "import asyncio\n"
                "import edge_tts\n"
                "async def main():\n"
                f"    communicate = edge_tts.Communicate({repr(text)}, {repr(voice)})\n"
                f"    await communicate.save({repr(temp_path)})\n"
                "asyncio.run(main())\n"
            )
            subprocess.run([sys.executable, "-c", python_code], check=True, capture_output=True, text=True)

            aplay_bin = shutil.which("aplay")
            ffmpeg_bin = shutil.which("ffmpeg")
            if ffmpeg_bin and aplay_bin:
                # ffmpeg decodifica para PCM S16LE e pipe para aplay
                ffmpeg_cmd = [
                    ffmpeg_bin,
                    "-y",
                    "-i", temp_path,
                    "-f", "s16le",
                    "-acodec", "pcm_s16le",
                    "-ar", "24000",
                    "-ac", "1",
                    "-"
                ]
                ffmpeg_proc = subprocess.Popen(
                    ffmpeg_cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL
                )
                aplay_proc = subprocess.Popen(
                    [aplay_bin, "-r", "24000", "-f", "S16_LE", "-c", "1", "-"],
                    stdin=ffmpeg_proc.stdout,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )
                aplay_proc.wait()
                ffmpeg_proc.wait()
                return True
            else:
                logger.warning("ffmpeg ou aplay ausente para reprodução de edge-tts.")
                return False
        finally:
            if os.path.exists(temp_path):
                os.unlink(temp_path)
    except Exception as e:
        logger.warning(f"edge-tts falhou (provavelmente offline ou sem conexão): {e}")
        return False


def speak_text_with_preset(text: str, preset: dict | None = None) -> None:
    """Sintetiza texto usando parâmetros de um preset de voz."""
    if not text:
        return
    text = preparar_para_voz(text)

    # Import tardio para evitar ciclo
    from .config import PIPER_MODEL_PATH, PIPER_CONFIG_PATH

    if preset is None:
        try:
            from .voices import get_active_preset
            preset = get_active_preset()
        except Exception:
            preset = {}

    # Cloud TTS is opt-in. Default must remain local-first.
    if preset.get("provider") == "edge-tts" and preset.get("voice"):
        if os.getenv("KORA_ENABLE_CLOUD_TTS") == "1":
            logger.info(f"Tentando síntese neural premium via edge-tts ({preset['voice']})...")
            if speak_edge_tts(text, preset["voice"]):
                return
            logger.info("Falha na síntese neural, recorrendo ao fallback local...")
        else:
            logger.info("edge-tts configurado, mas desabilitado por default. Use KORA_ENABLE_CLOUD_TTS=1 para opt-in.")

    piper_bin = _find_piper_bin()
    aplay_bin = shutil.which("aplay")

    if not piper_bin:
        logger.warning("piper-tts não encontrado no PATH — TTS desabilitado.")
        _fallback_spd_say(text)
        return

    model_path = Path(PIPER_MODEL_PATH)
    if not model_path.exists():
        logger.warning(
            f"Modelo Piper não encontrado: {model_path}\n"
            "  → Execute: kora voice models install piper faber"
        )
        _fallback_spd_say(text)
        return

    piper_cmd = [piper_bin, "--model", str(model_path), "--output_raw"]

    # Config opcional
    config_path = Path(PIPER_CONFIG_PATH)
    if config_path.exists():
        piper_cmd += ["--config", str(config_path)]

    # length_scale: >1 = mais lento/pausado, <1 = mais rápido.
    # Default 1.1 = ~10% mais lento — voz feminina natural, sem pressa.
    length_scale = preset.get("length_scale", 1.1)
    piper_cmd += ["--length_scale", str(length_scale)]

    if preset.get("noise_scale"):
        piper_cmd += ["--noise_scale", str(preset["noise_scale"])]
    if preset.get("noise_w"):
        piper_cmd += ["--noise_w", str(preset["noise_w"])]

    try:
        piper_proc = subprocess.Popen(
            piper_cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )

        if aplay_bin:
            aplay_proc = subprocess.Popen(
                [aplay_bin, "-r", "22050", "-f", "S16_LE", "-t", "raw", "-"],
                stdin=piper_proc.stdout,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            piper_proc.stdin.write(text.encode("utf-8"))
            piper_proc.stdin.close()
            aplay_proc.wait()
        else:
            piper_proc.stdin.write(text.encode("utf-8"))
            piper_proc.stdin.close()
            piper_proc.wait()
            logger.warning("aplay não encontrado — áudio não reproduzido.")
    except Exception as e:
        logger.error(f"TTS falhou: {e}")
        _fallback_spd_say(text)

