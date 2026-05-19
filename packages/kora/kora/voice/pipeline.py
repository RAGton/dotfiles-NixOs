# =============================================================================
# Kora Voice — Pipeline
#
# Loop principal de interação por voz:
#   record → STT → Kora Orchestrator → TTS
# Inclui memória de conversa, animação de pensando e UX melhorada.
# =============================================================================

import asyncio
import logging
import os
import shutil
import subprocess
import sys
import threading
import time
from datetime import datetime
from pathlib import Path

from .recorder import KoraRecorder
from .stt import transcribe_audio
from .tts import speak_text
from .vad import record_with_vad
from .signals import play_wake, play_thinking, play_done, play_error
from ..core.orchestrator import process_message


def play_audio_signal(signal_type: str) -> None:
    """Play a WAV file via aplay for named signal events.

    Looks for ``kora_<signal_type>.wav`` in KORA_SFX_DIR; falls back to the
    programmatic tones in .signals when the file is absent or aplay is missing.

    signal_type: 'active'   — wake-word confirmed
                 'thinking'  — orchestrator starting to process
    """
    from .config import KORA_SFX_DIR

    _wav = {"active": "kora_active.wav", "thinking": "kora_thinking.wav"}.get(signal_type)
    _fallback = {"active": play_wake, "thinking": play_thinking}.get(signal_type)

    if _wav and (KORA_SFX_DIR / _wav).exists() and shutil.which("aplay"):
        try:
            subprocess.Popen(
                ["aplay", "-q", str(KORA_SFX_DIR / _wav)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            return
        except Exception as exc:
            logger.debug("aplay failed for signal=%s: %s", signal_type, exc)

    if _fallback:
        _fallback()
from ..core.conversation import append_turn, detect_followup_complaint

logger = logging.getLogger("kora.voice.pipeline")


def is_voice_enabled() -> bool:
    """
    Verifica se a síntese de voz (TTS) da Kora está ativada.
    Ordem de precedência:
      1. Existência do arquivo /run/kryonix/kora_mute (se existir, voz desativada)
      2. Variável de ambiente KORA_VOICE_ENABLED
      3. ~/.config/kryonix/kora.env
      4. /etc/kryonix/kora.env
    Retorna True por padrão se não configurado.
    """
    if Path("/run/kryonix/kora_mute").exists():
        return False

    env_val = os.environ.get("KORA_VOICE_ENABLED")
    if env_val is not None:
        return env_val.lower() not in ("false", "0", "no", "off", "disable", "disabled")

    def parse_env_file(path: Path) -> str | None:
        if not path.exists():
            return None
        try:
            with open(path, "r") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    if line.startswith("export "):
                        line = line[7:]
                    if "=" in line:
                        k, v = line.split("=", 1)
                        if k.strip() == "KORA_VOICE_ENABLED":
                            return v.strip().strip("'\"")
        except Exception:
            pass
        return None

    # ~/.config/kryonix/kora.env
    user_val = parse_env_file(Path.home() / ".config" / "kryonix" / "kora.env")
    if user_val is not None:
        return user_val.lower() not in ("false", "0", "no", "off", "disable", "disabled")

    # /etc/kryonix/kora.env
    global_val = parse_env_file(Path("/etc/kryonix/kora.env"))
    if global_val is not None:
        return global_val.lower() not in ("false", "0", "no", "off", "disable", "disabled")

    return True


# ── Terminal UX helpers ──────────────────────────────────────────────────────

import re

# Box-drawing characters
_H = "─"
_TL, _TR, _BL, _BR = "╭", "╮", "╰", "╯"
_V = "│"
_WIDTH = 56

CLEAN_ANSI_RE = re.compile(
    r"(?:\x1b|\\x1b|\\033|\\u001b)\[[0-9;?]*[A-Za-z]" # Standard ANSI codes
    r"|\[[0-9]+(?:;[0-9]+)*m"                        # bracket + color codes (e.g. [0m, [38;5;114m)
    r"|(?:\b|;)[0-9]+;[0-9]+(?:;[0-9]+)*m"            # color codes with semicolons (e.g. 38;5;114m, ;166m)
)
CONTROL_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")

def clean_terminal_text(text: str) -> str:
    text = CLEAN_ANSI_RE.sub("", text)
    text = CONTROL_RE.sub("", text)
    return text.strip()

# Thinking animation frames
_THINK_FRAMES = [
    ("⠋", "⟡"), ("⠙", "✦"), ("⠹", "✧"),
    ("⠸", "⟡"), ("⠼", "✦"), ("⠴", "✧"),
    ("⠦", "⟡"), ("⠧", "✦"), ("⠇", "✧"), ("⠏", "⟡"),
]


def _box(label: str, text: str, color_code: str = "36") -> None:
    """Print text in a styled box."""
    text = clean_terminal_text(text)
    lines = text.split("\n")
    inner_w = _WIDTH - 4  # padding inside box

    print(f"\033[{color_code}m{_TL}{_H} {label} {_H * (_WIDTH - len(label) - 4)}{_TR}\033[0m")
    for line in lines:
        # word-wrap long lines
        while len(line) > inner_w:
            print(f"\033[{color_code}m{_V}\033[0m {line[:inner_w]} \033[{color_code}m{_V}\033[0m")
            line = line[inner_w:]
        padding = " " * (inner_w - len(line))
        print(f"\033[{color_code}m{_V}\033[0m {line}{padding} \033[{color_code}m{_V}\033[0m")
    print(f"\033[{color_code}m{_BL}{_H * (_WIDTH - 2)}{_BR}\033[0m")


class _ThinkingAnimation:
    """Spinner animation that runs in a background thread."""

    def __init__(self):
        self._running = False
        self._thread = None
        self._start_time = 0.0

    def start(self):
        self._running = True
        self._start_time = time.monotonic()
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()

    def stop(self):
        self._running = False
        if self._thread:
            self._thread.join(timeout=1)
        # Clear the line
        sys.stdout.write("\r" + " " * 60 + "\r")
        sys.stdout.flush()

    def _loop(self):
        idx = 0
        while self._running:
            elapsed = time.monotonic() - self._start_time
            frame_spinner, frame_star = _THINK_FRAMES[idx % len(_THINK_FRAMES)]
            sys.stdout.write(
                f"\r  \033[35mKora pensando {frame_spinner}{frame_star}\033[0m "
                f"\033[2m{elapsed:.1f}s\033[0m"
            )
            sys.stdout.flush()
            idx += 1
            time.sleep(0.12)


def get_natural_greeting(user: str = "Ragton") -> str:
    """Return a natural greeting based on the time of day."""
    hour = datetime.now().hour
    if 5 <= hour < 12:
        period = "Bom dia"
    elif 12 <= hour < 18:
        period = "Boa tarde"
    else:
        period = "Boa noite"

    if user in ("rocha", "Ragton"):
        return f"{period}, Ragton. Estou online e pronta para acompanhar você."
    else:
        return "Olá. Ainda não reconheci sua identidade, mas posso conversar de forma limitada."


async def listen_and_respond(push_to_talk: bool = True, user: str = "rocha", single_turn: bool = False):
    """
    Complete voice loop: record → STT → Kora → TTS.
    Persists conversation turns for context.
    """
    from .config import KORA_VOICE_TMP_DIR, ensure_voice_dirs
    ensure_voice_dirs()

    recorder = KoraRecorder()

    print()
    print(f"\033[35m{'═' * _WIDTH}\033[0m")
    print(f"\033[35m{'':>14}KORA VOICE — MODO ESCUTA\033[0m")
    if push_to_talk:
        print(f"\033[2m{'':>16}Push-to-Talk (ENTER)\033[0m")
    else:
        print(f"\033[2m{'':>12}VAD — para após 1s silêncio\033[0m")
    print(f"\033[35m{'═' * _WIDTH}\033[0m")

    # Initial greeting only if not single turn (to avoid greeting on every wake-word)
    if not single_turn:
        greeting = get_natural_greeting(user)
        _box("Kora", greeting, "35")
        if is_voice_enabled():
            speak_text(greeting)

    try:
        while True:
            if push_to_talk:
                from ..utils.lock import HardwareLock
                with HardwareLock():
                    print(f"\n  \033[2m[Pressione ENTER para falar ou Ctrl+C para sair]\033[0m")
                    input()
                    print("  \033[33m🎙 Gravando... (ENTER para parar)\033[0m")
                    audio_path = recorder.record_until_keypress("last_input.wav")
            else:
                from ..utils.lock import HardwareLock
                with HardwareLock():
                    if not single_turn:
                        print(f"\n  \033[2m[Fale a qualquer momento ou Ctrl+C para sair]\033[0m")
                    play_wake()
                    print("  \033[33m🎙 Ouvindo (gravando 5s)...\033[0m")
                    audio_path = recorder.record_to_file("last_input.wav", seconds=5)

            print("  \033[2m... processando áudio ...\033[0m")
            text = transcribe_audio(audio_path, user=user)

            # Apply personal normalization before sending text to KoraMind.
            try:
                from kora.core.normalizer import normalize_text
                text = normalize_text(text, user).normalized
            except Exception as le_err:
                logger.warning(f"Erro ao aplicar normalização no pipeline de voz: {le_err}")

            if not text or text.strip() in ["[Erro na transcrição]", ""] or len(text.strip()) < 3:
                print("  \033[2m(fala não compreendida)\033[0m")
                _box("Kora", "Não consegui entender bem. Pode repetir?", "35")
                if is_voice_enabled():
                    speak_text("Não consegui entender bem. Pode repetir?")
                if single_turn:
                    break
                continue

            # Show user input
            _box("Você", text.strip(), "36")

            # Detect followup complaint
            if detect_followup_complaint(text):
                logger.info("Followup complaint detected — injecting recovery context")

            # Thinking animation + signal
            play_audio_signal("thinking")
            spinner = _ThinkingAnimation()
            spinner.start()

            try:
                resp = await process_message(
                    text,
                    session_id="voice-current",
                    user=user,
                    mode="auto",
                    is_voice=True
                )
            finally:
                spinner.stop()

            answer = resp.get("answer", "Sem resposta.")
            elapsed = resp.get("elapsed_sec", 0)
            mode_used = resp.get("mode", "?")

            play_done()

            # Show Kora response
            _box("Kora", answer, "35")
            print(f"  \033[2m[{mode_used} | {elapsed:.1f}s]\033[0m")

            # Speak
            if is_voice_enabled():
                speak_text(answer)

            if single_turn:
                break

    except KeyboardInterrupt:
        print(f"\n  \033[2m[Encerrando modo voz]\033[0m\n")
        raise
    except asyncio.CancelledError:
        print(f"\n  \033[2m[Operação cancelada]\033[0m\n")
    except Exception as e:
        play_error()
        logger.error(f"Pipeline error: {e}")
        print(f"\n  \033[31m[Erro fatal no pipeline de voz: {e}]\033[0m\n")


async def run_voice_pipeline(user: str = "rocha") -> None:
    """
    Standalone main voice orchestration pipeline:
    1. Waits for WakeWordEngine trigger.
    2. Uses HardwareLock to record 5 seconds of audio.
    3. Transcribes using faster-whisper.
    4. Submits to orchestrator.py (GraphRAG).
    5. Receives response.
    6. Synthesizes response using piper-tts (TTS).
    """
    from .wakeword import WakeWordEngine
    from ..utils.lock import HardwareLock
    from .tts import synthesize_text

    engine = WakeWordEngine()
    recorder = KoraRecorder()
    loop = asyncio.get_running_loop()

    logger.info("Pipeline de voz iniciado. Aguardando wake-word...")
    try:
        while True:
            # 1. Wait for wake-word engine trigger
            detected = await loop.run_in_executor(None, engine.listen)
            if detected:
                logger.info("Wake-word detectada no pipeline principal!")
                # 4. Exclusividade: Use HardwareLock to protect microphone recording
                with HardwareLock():
                    engine.stream.close()
                    play_audio_signal("active")
                    # 2. Record 5 seconds of audio
                    audio_path = recorder.record_to_file("last_input.wav", seconds=5)

                # 3. Transcribe audio (STT)
                text = transcribe_audio(audio_path, user=user)
                if not text or len(text.strip()) < 3:
                    continue

                play_audio_signal("thinking")
                # 4. Send to orchestrator.py (GraphRAG) and 5. Receive response
                resp = await process_message(
                    text,
                    session_id="voice-current",
                    user=user,
                    mode="auto",
                    is_voice=True
                )
                answer = resp.get("answer", "Sem resposta.")
                play_done()

                # 6. Synthesize response (TTS)
                if is_voice_enabled():
                    synthesize_text(answer)
            await asyncio.sleep(0.02)
    except KeyboardInterrupt:
        logger.info("Pipeline de voz interrompido pelo usuário.")
    except Exception as e:
        logger.error(f"Erro fatal no pipeline de voz: {e}")


def chat(query: str) -> None:
    """
    Processa uma consulta em linguagem natural a partir da CLI (NLP-First).
    Usa animação de pensamento e exibe a resposta de Kora de forma elegante.
    """
    user = os.environ.get("USER") or "rocha"
    _box("Você", query.strip(), "36")
    
    play_audio_signal("thinking")
    spinner = _ThinkingAnimation()
    spinner.start()

    try:
        resp = asyncio.run(process_message(
            query,
            session_id="cli-chat",
            user=user,
            mode="auto",
            is_voice=False
        ))
    except Exception as e:
        play_error()
        spinner.stop()
        print(f"\033[31mErro ao obter resposta da assistente: {e}\033[0m", file=sys.stderr)
        return
    finally:
        spinner.stop()
        
    play_done()
    
    answer = resp.get("answer", "Sem resposta.")
    elapsed = resp.get("elapsed_sec", 0.0)
    mode_used = resp.get("mode", "auto")
    
    _box("Kora", answer, "35")
    print(f"  \033[2m[{mode_used} | {elapsed:.1f}s]\033[0m")


