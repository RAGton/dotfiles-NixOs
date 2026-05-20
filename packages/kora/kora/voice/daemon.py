import asyncio
import contextlib
import json
import logging
import os
import signal
import sys
import time
from enum import Enum
from pathlib import Path

from .exceptions import HardwareAccessError, ServiceUnreachable
from .monitor import ping_orchestrator, retry_connection
from .pipeline import listen_and_respond
from .vad import _is_speech
from .wakeword import WakeWordEngine, _CHUNK_BYTES, _keyword_detect

logger = logging.getLogger("kora.voice.daemon")


class KoraVoiceState(Enum):
    IDLE = "idle"
    LISTENING = "listening"
    THINKING = "thinking"
    SPEAKING = "speaking"
    MUTED = "muted"
    BLOCKED = "blocked"
    CONFIRMING = "confirming"
    RECONNECTING = "reconnecting"


def setup_voice_logging() -> None:
    log_dir = Path.home() / ".kryonix" / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)

    fmt = logging.Formatter("%(asctime)s [%(levelname)s] %(name)s: %(message)s")
    fh = logging.FileHandler(log_dir / "voice.log", encoding="utf-8")
    fh.setFormatter(fmt)
    fh.setLevel(logging.INFO)

    ch = logging.StreamHandler()
    ch.setFormatter(fmt)
    ch.setLevel(logging.INFO)

    root = logging.getLogger("kora")
    root.setLevel(logging.INFO)
    root.addHandler(fh)
    root.addHandler(ch)


class KoraVoiceDaemon:
    _HEARTBEAT_INTERVAL = 30.0
    _MAX_QUEUE_CHUNKS = 10  # ~300ms at 30ms/chunk; drain above this

    def __init__(self) -> None:
        self.state = KoraVoiceState.IDLE
        self.muted = False
        self.running = False
        self.wakeword_engine = WakeWordEngine()
        self._loop: asyncio.AbstractEventLoop | None = None
        self.state_file = Path(f"/run/user/{os.getuid()}/kryonix/voice_state.json")
        self._reconnect_ok: asyncio.Event = asyncio.Event()
        self._heartbeat_task: asyncio.Task | None = None
        self._reader_task: asyncio.Task | None = None
        self._processor_task: asyncio.Task | None = None
        self._audio_queue: asyncio.Queue[bytes] = asyncio.Queue()

    # ── State management ────────────────────────────────────────────────────

    def update_state(self, state: KoraVoiceState) -> None:
        if self.state == state:
            return
        self.state = state
        logger.info("State → %s", state.value)
        try:
            self.state_file.parent.mkdir(parents=True, exist_ok=True)
            self.state_file.write_text(json.dumps({
                "state": state.value,
                "muted": self.muted,
                "running": self.running,
                "timestamp": time.time(),
            }))
        except Exception as e:
            logger.warning("Failed to write state file: %s", e)

    # ── Heartbeat ────────────────────────────────────────────────────────────

    async def _heartbeat_cycle(self) -> None:
        """Single health probe. Extracted for testability."""
        healthy = await ping_orchestrator()
        if healthy:
            if self.state == KoraVoiceState.RECONNECTING:
                logger.info("Orchestrator reachable again — resuming normal operation.")
                self._reconnect_ok.set()
                self.update_state(KoraVoiceState.IDLE)
        else:
            if self.state != KoraVoiceState.RECONNECTING:
                logger.warning(
                    "Orchestrator unreachable — entering RECONNECTING state."
                )
            self._reconnect_ok.clear()
            self.update_state(KoraVoiceState.RECONNECTING)

    @retry_connection
    async def _reconnect_probe(self) -> None:
        """Called during RECONNECTING. Retries with exponential backoff until healthy."""
        healthy = await ping_orchestrator()
        if not healthy:
            raise ServiceUnreachable("Orchestrator still unreachable")
        logger.info("Reconnected to orchestrator after outage.")
        self._reconnect_ok.set()
        self.update_state(KoraVoiceState.IDLE)

    async def _heartbeat_loop(self) -> None:
        """Background task: probes every HEARTBEAT_INTERVAL; uses backoff in RECONNECTING."""
        while self.running:
            try:
                if self.state == KoraVoiceState.RECONNECTING:
                    await self._reconnect_probe()
                else:
                    await asyncio.sleep(self._HEARTBEAT_INTERVAL)
                    await self._heartbeat_cycle()
            except asyncio.CancelledError:
                raise
            except Exception as e:
                logger.error("Heartbeat loop error: %s", e)
                await asyncio.sleep(5.0)

    # ── Audio pipeline ───────────────────────────────────────────────────────

    async def _stdin_reader(self) -> None:
        """Reads raw PCM from stdin and pushes 30ms chunks to the audio queue.

        Always runs regardless of state so pw-record never stalls on a full
        pipe buffer.  Drains the queue when lag exceeds _MAX_QUEUE_CHUNKS.
        """
        loop = asyncio.get_running_loop()
        while self.running:
            try:
                chunk = await loop.run_in_executor(
                    None, sys.stdin.buffer.read, _CHUNK_BYTES
                )
            except Exception as e:
                logger.error("stdin reader error: %s", e)
                self.running = False
                break
            if not chunk:
                logger.warning("stdin EOF — pw-record may have exited")
                self.running = False
                break
            qsize = self._audio_queue.qsize()
            if qsize > self._MAX_QUEUE_CHUNKS:
                drained = 0
                while not self._audio_queue.empty():
                    try:
                        self._audio_queue.get_nowait()
                        drained += 1
                    except asyncio.QueueEmpty:
                        break
                logger.debug("Queue drained %d chunks (lag was %d chunks)", drained, qsize)
            await self._audio_queue.put(chunk)

    async def _audio_processor(self) -> None:
        """Consumes audio chunks: VAD → speech accumulation → Whisper keyword check.

        Flow:
          1. VAD filters silence — no CPU spent on quiet frames.
          2. When speech starts, frames are accumulated into a buffer.
          3. After ~500ms of post-speech silence the buffer is transcribed
             by faster-whisper; if the wake word ("kora" / aliases) is found
             handle_trigger() is scheduled.

        The Whisper-based approach lets the user say "Kora" (or any configured
        wake word) without a custom neural model.
        """
        loop = asyncio.get_running_loop()

        # ── Speech-accumulation state ────────────────────────────────────────
        _speech_buf: bytearray = bytearray()
        _in_speech: bool = False
        _silence_chunks: int = 0
        # 17 × 30ms ≈ 500ms of silence → end of utterance
        _SILENCE_END = 17
        # 3 seconds of audio max (safety cap)
        _MAX_BUF = _CHUNK_BYTES * 100
        # At least 3 chunks before we bother transcribing
        _MIN_BUF = _CHUNK_BYTES * 3

        while self.running:
            try:
                chunk = await asyncio.wait_for(self._audio_queue.get(), timeout=1.0)
            except asyncio.TimeoutError:
                # Flush a stale open buffer if we somehow got stuck
                if _in_speech and _silence_chunks >= _SILENCE_END:
                    _speech_buf.clear(); _in_speech = False; _silence_chunks = 0
                continue
            except asyncio.CancelledError:
                break

            # Only detect when idle and unmuted; drain silently otherwise.
            if self.state != KoraVoiceState.IDLE or self.muted:
                _speech_buf.clear(); _in_speech = False; _silence_chunks = 0
                continue

            # ── VAD gate ────────────────────────────────────────────────────
            try:
                is_speech = await loop.run_in_executor(None, _is_speech, chunk)
            except Exception:
                is_speech = True  # fail open

            if is_speech:
                _speech_buf.extend(chunk)
                _in_speech = True
                _silence_chunks = 0
                # Safety cap: keep only the last 3 seconds
                if len(_speech_buf) > _MAX_BUF:
                    _speech_buf = bytearray(_speech_buf[-_MAX_BUF:])
            elif _in_speech:
                # Trailing silence after speech
                _speech_buf.extend(chunk)
                _silence_chunks += 1

                if _silence_chunks >= _SILENCE_END:
                    audio_snapshot = bytes(_speech_buf)
                    _speech_buf = bytearray(); _in_speech = False; _silence_chunks = 0

                    if len(audio_snapshot) < _MIN_BUF:
                        continue  # too short to bother

                    # ── Whisper keyword check ────────────────────────────────
                    try:
                        detected = await loop.run_in_executor(
                            None, _keyword_detect, audio_snapshot
                        )
                    except Exception as exc:
                        logger.error("Keyword detection error: %s", exc)
                        continue

                    if detected:
                        asyncio.create_task(self.handle_trigger())

    # ── Interaction trigger ──────────────────────────────────────────────────

    async def handle_trigger(self) -> None:
        if self.state == KoraVoiceState.RECONNECTING:
            logger.warning("Wake-word trigger skipped — daemon in RECONNECTING state.")
            return

        self.update_state(KoraVoiceState.LISTENING)
        logger.info("Wake-word triggered — starting interaction.")
        try:
            # pw-record keeps streaming; _audio_processor skips detection while
            # state != IDLE, so chunks are drained without being processed.
            await listen_and_respond(push_to_talk=False, single_turn=True)
        except (OSError, IOError) as e:
            logger.error("Audio hardware error: %s", e)
            raise HardwareAccessError(str(e)) from e
        except Exception as e:
            logger.error("Interaction error: %s", e)
        finally:
            if self.state != KoraVoiceState.RECONNECTING:
                self.update_state(KoraVoiceState.IDLE)

    # ── Main loop ────────────────────────────────────────────────────────────

    async def start(self) -> None:
        self.running = True
        self._loop = asyncio.get_running_loop()
        self._reconnect_ok.set()

        self._heartbeat_task = asyncio.create_task(
            self._heartbeat_loop(), name="kora-voice-heartbeat"
        )
        self._reader_task = asyncio.create_task(
            self._stdin_reader(), name="kora-voice-reader"
        )
        self._processor_task = asyncio.create_task(
            self._audio_processor(), name="kora-voice-processor"
        )
        self.update_state(KoraVoiceState.IDLE)
        logger.info("Kora Voice Daemon: reader + VAD processor started.")

        mute_file = Path("/var/lib/kryonix/kora/voice/muted")
        last_log_time = 0.0
        try:
            while self.running:
                self.muted = mute_file.exists()

                if self.muted:
                    if self.state == KoraVoiceState.IDLE:
                        self.update_state(KoraVoiceState.MUTED)
                elif self.wakeword_engine.is_locked():
                    if self.state == KoraVoiceState.IDLE:
                        self.update_state(KoraVoiceState.BLOCKED)
                elif self.state in (KoraVoiceState.MUTED, KoraVoiceState.BLOCKED):
                    self.update_state(KoraVoiceState.IDLE)

                if self.state == KoraVoiceState.IDLE:
                    now = time.monotonic()
                    if now - last_log_time > 15.0:
                        logger.info("Kora aguardando ativação...")
                        last_log_time = now

                # If a worker task died unexpectedly, stop cleanly
                for task in (self._reader_task, self._processor_task):
                    if task.done() and not task.cancelled():
                        exc = task.exception() if not task.cancelled() else None
                        if exc:
                            logger.error("Audio task died: %s", exc)
                        self.running = False
                        break

                await asyncio.sleep(0.5)

        except asyncio.CancelledError:
            logger.info("Daemon main loop cancelled.")
        finally:
            await self._shutdown()

    async def _shutdown(self) -> None:
        self.running = False
        for task in (self._reader_task, self._processor_task, self._heartbeat_task):
            if task and not task.done():
                task.cancel()
                with contextlib.suppress(asyncio.CancelledError):
                    await task
        logger.info("Kora Voice Daemon: stopped.")

    def stop(self, *args) -> None:
        """Signal-safe stop."""
        logger.info("Stop requested (signal received).")
        self.running = False
        for task in (self._reader_task, self._processor_task, self._heartbeat_task):
            if task and not task.done():
                task.cancel()

    def get_status(self) -> dict:
        return {
            "state": self.state.value,
            "muted": self.muted,
            "running": self.running,
        }


async def run_daemon() -> None:
    setup_voice_logging()
    daemon = KoraVoiceDaemon()

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, daemon.stop)
        except NotImplementedError:
            pass

    await daemon.start()
