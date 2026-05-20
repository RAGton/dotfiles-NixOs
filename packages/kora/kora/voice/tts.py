# =============================================================================
# Kora Voice — TTS (Text to Speech)
# =============================================================================
# Usa piper-tts (do Nix PATH) com modelo .onnx PT-BR.
# O modelo é resolvido dinamicamente via config.py (current.onnx ou fallback).
# =============================================================================

import shutil
import subprocess
import logging
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


def aplicar_prosodia_artificial(texto: str) -> list[str]:
    """
    Divide o texto em blocos/frases para inserir pausas artificiais (prosódia).
    Adiciona pausas de 200ms em vírgulas, transições de assunto ou pausas dramáticas.
    """
    import re
    if not texto:
        return []

    # Normalizar reticências
    texto = texto.replace("...", "…")

    # Inserir [PAUSE] após pontuação (, ; : …)
    texto = re.sub(r'(\s*(?:,|;|:|…)\s*)', r'\1 [PAUSE] ', texto)

    # Inserir [PAUSE] antes de palavras de transição comuns,
    # se não houver pontuação ou pausa logo antes.
    def repl_transicao(match):
        pre = match.group(1)
        word = match.group(2)
        if re.search(r'(?:,|;|:|…|\.|\!|\?|\[PAUSE\])\s*$', pre):
            return match.group(0)
        return f"{pre}[PAUSE] {word}"

    texto = re.sub(r'(\s+)\b(mas|porém|contudo|entretanto|então|pois|portanto|ou\s+seja)\b', repl_transicao, texto, flags=re.IGNORECASE)

    # Divide por [PAUSE] e limpa espaços
    chunks = [c.strip() for c in texto.split("[PAUSE]")]

    # Filtra chunks vazios ou sem letras
    result = []
    for c in chunks:
        if c and any(char.isalnum() for char in c):
            result.append(c)

    return result


def humanizar_resposta_ferramentas(texto: str, tools_called: list[str] | None = None) -> str:
    """Precede a resposta com uma interjeição humanizada se ferramentas foram chamadas."""
    if not tools_called:
        return texto

    # Se qualquer ferramenta de busca/grafo foi acionada:
    if any("graph" in t or "search" in t for t in tools_called):
        try:
            from .daemon import INTERJEICOES_PROCESSAMENTO
            import random
            prefixo = random.choice(INTERJEICOES_PROCESSAMENTO)
            # Previne adicionar se o texto já começar com algo parecido
            if not texto.strip().startswith(("Deixa eu", "Só um segundo", "Deixe-me", "Vou dar", "Acessando", "Buscando")):
                return prefixo + texto
        except Exception:
            pass

    return texto


def speak_text(text: str, tools_called: list[str] | None = None) -> None:
    """Sintetiza texto com o preset ativo."""
    speak_text_with_preset(text, preset=None, tools_called=tools_called)


def synthesize_text(text: str, tools_called: list[str] | None = None) -> None:
    """Alias retrocompatível → speak_text_with_preset com preset padrão."""
    speak_text_with_preset(text, preset=None, tools_called=tools_called)


def _fallback_spd_say(text: str) -> None:
    """Fallback via spd-say se disponível."""
    spd = shutil.which("spd-say")
    if spd:
        try:
            subprocess.run([spd, text], check=True, timeout=10)
        except Exception:
            pass


# ── async-to-sync bridge ──────────────────────────────────────────────────────

def _run_sync(coro) -> None:
    """Executa corrotina async a partir de código síncrono (thread isolada)."""
    import threading
    exc: list[BaseException] = []

    def _runner():
        import asyncio
        try:
            asyncio.run(coro)
        except BaseException as e:
            exc.append(e)

    t = threading.Thread(target=_runner, daemon=True)
    t.start()
    t.join()
    if exc:
        raise exc[0]


def _play_wav(path: Path) -> None:
    ffplay_bin = shutil.which("ffplay")
    aplay_bin  = shutil.which("aplay")
    if ffplay_bin:
        subprocess.run(
            [ffplay_bin, "-nodisp", "-autoexit", "-loglevel", "quiet", str(path)],
            check=True,
        )
    elif aplay_bin:
        subprocess.run([aplay_bin, str(path)], check=True)
    else:
        logger.warning("Nenhum reprodutor de áudio encontrado (ffplay ou aplay)")


# ── public synthesis API ──────────────────────────────────────────────────────

def speak_text_with_preset(text: str, preset: dict | None = None,
                            tools_called: list[str] | None = None) -> None:
    """Sintetiza texto usando a cadeia de providers configurada."""
    if not text:
        return
    text = humanizar_resposta_ferramentas(text, tools_called)
    text = preparar_para_voz(text)

    if preset is None:
        try:
            from .voices import get_active_preset
            preset = get_active_preset()
        except Exception:
            preset = {}

    import tempfile
    from .providers import build_provider_chain

    provider = build_provider_chain(preset)

    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        out_wav = Path(f.name)

    try:
        _run_sync(provider.synthesize(text, out_wav))
        if out_wav.exists() and out_wav.stat().st_size > 44:
            _play_wav(out_wav)
        else:
            logger.error("Provider não gerou áudio válido")
            _fallback_spd_say(text)
    except Exception as exc:
        logger.error("TTS pipeline falhou: %s", exc)
        _fallback_spd_say(text)
    finally:
        try:
            out_wav.unlink(missing_ok=True)
        except Exception:
            pass
