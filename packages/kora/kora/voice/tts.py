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
    transicoes = r'\b(mas|porém|contudo|entretanto|então|pois|portanto|ou\s+seja)\b'
    
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
    """Sintetiza texto com Piper usando o preset ativo."""
    speak_text_with_preset(text, preset=None, tools_called=tools_called)


def synthesize_text(text: str, tools_called: list[str] | None = None) -> None:
    """
    Sintetiza texto usando piper-tts para um arquivo WAV temporário
    e o reproduz usando ffplay ou aplay.
    Aplica parâmetros de qualidade para voz mais natural.
    """
    if not text:
        return
    text = humanizar_resposta_ferramentas(text, tools_called)
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
            stderr=None,
        )
        piper_proc.communicate(input=text.encode("utf-8"))
        piper_proc.wait()

        # Check if the temporary WAV file was written successfully
        if os.path.exists(temp_wav_path) and os.path.getsize(temp_wav_path) > 0:
            logger.info("Enviando áudio para o aplay/ffplay: %s bytes", os.path.getsize(temp_wav_path))
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


def speak_text_with_preset(text: str, preset: dict | None = None, tools_called: list[str] | None = None) -> None:
    """Sintetiza texto usando parâmetros de um preset de voz."""
    if not text:
        return
    text = humanizar_resposta_ferramentas(text, tools_called)
    text = preparar_para_voz(text)

    # Import tardio para evitar ciclo
    from .config import PIPER_MODEL_PATH, PIPER_CONFIG_PATH

    if preset is None:
        try:
            from .voices import get_active_preset
            preset = get_active_preset()
        except Exception:
            preset = {}

    if preset.get("provider") == "edge-tts":
        logger.info(f"Tentando edge-tts com voz {preset.get('voice')}...")
        if speak_edge_tts(text, preset["voice"]):
            return
        logger.warning("Falha ao usar edge-tts, caindo de volta para Piper local offline.")

    piper_bin = _find_piper_bin()
    aplay_bin = shutil.which("aplay")

    if not piper_bin:
        logger.warning("piper-tts não encontrado no PATH — TTS desabilitado.")
        _fallback_spd_say(text)
        return

    # Dynamic model resolution based on preset
    model_path = None
    config_path = None
    preset_model_name = preset.get("model")
    if preset_model_name:
        try:
            from .models import PIPER_VOICES, PIPER_DIR
            if preset_model_name in PIPER_VOICES:
                meta = PIPER_VOICES[preset_model_name]
                p_model = PIPER_DIR / meta["local_model"]
                p_config = PIPER_DIR / meta["local_config"]
                if p_model.exists():
                    model_path = p_model
                    config_path = p_config
                    logger.info(f"Usando modelo do preset '{preset_model_name}': {model_path.name}")
        except Exception as e:
            logger.debug(f"Erro ao tentar resolver modelo do preset '{preset_model_name}': {e}")

    # Fallback to default PIPER_MODEL_PATH / PIPER_CONFIG_PATH if not resolved or not found
    if not model_path or not model_path.exists():
        model_path = Path(PIPER_MODEL_PATH)
        config_path = Path(PIPER_CONFIG_PATH)
        logger.info(f"Usando modelo padrão: {model_path.name if model_path else 'Nenhum'}")

    if not model_path or not model_path.exists():
        logger.warning(
            f"Modelo Piper não encontrado: {model_path}\n"
            "  → Execute: kora voice models install piper edresson"
        )
        _fallback_spd_say(text)
        return

    piper_cmd = [piper_bin, "--model", str(model_path), "--output_raw"]

    if config_path and config_path.exists():
        piper_cmd += ["--config", str(config_path)]

    # length_scale: >1 = mais lento/pausado, <1 = mais rápido.
    # Default 1.1 = ~10% mais lento — voz feminina natural, sem pressa.
    length_scale = preset.get("length_scale", 1.1)
    piper_cmd += ["--length_scale", str(length_scale)]

    if preset.get("noise_scale"):
        piper_cmd += ["--noise_scale", str(preset["noise_scale"])]
    if preset.get("noise_w"):
        piper_cmd += ["--noise_w", str(preset["noise_w"])]

    # Aplicar prosódia dividindo o texto em blocos/sentenças
    chunks = aplicar_prosodia_artificial(text)
    if not chunks:
        chunks = [text]

    try:
        if aplay_bin:
            # Detect sample rate from config
            sample_rate = 22050
            if config_path and config_path.exists():
                try:
                    import json
                    with open(config_path, "r", encoding="utf-8") as f:
                        cfg_data = json.load(f)
                        sr = cfg_data.get("audio", {}).get("sample_rate")
                        if sr:
                            sample_rate = sr
                            logger.info(f"Detectado sample_rate do modelo: {sample_rate}Hz")
                except Exception as e:
                    logger.warning(f"Falha ao ler sample_rate do config de Piper: {e}")

            # Iniciamos um único processo do aplay para tocar toda a sequência continuamente
            aplay_proc = subprocess.Popen(
                [aplay_bin, "-r", str(sample_rate), "-f", "S16_LE", "-t", "raw", "-"],
                stdin=subprocess.PIPE,
                stdout=subprocess.DEVNULL,
                stderr=None,
            )
            
            # Silêncio de 200ms a sample_rate: sample_rate * 2 bytes * 0.2 segundos
            silence_bytes = b"\x00" * int(sample_rate * 2 * 0.2)
            
            for i, chunk in enumerate(chunks):
                piper_proc = subprocess.Popen(
                    piper_cmd,
                    stdin=subprocess.PIPE,
                    stdout=subprocess.PIPE,
                    stderr=None,
                )
                pcm_data, _ = piper_proc.communicate(input=chunk.encode("utf-8"))
                piper_proc.wait()
                
                if pcm_data:
                    logger.info("Enviando áudio para o aplay/ffplay: %s bytes", len(pcm_data))
                    try:
                        aplay_proc.stdin.write(pcm_data)
                    except BrokenPipeError:
                        logger.warning("aplay broken pipe durante reprodução de PCM.")
                        break
                
                # Injeta pausa de 200ms entre as sentenças/blocos
                if i < len(chunks) - 1:
                    try:
                        aplay_proc.stdin.write(silence_bytes)
                    except BrokenPipeError:
                        logger.warning("aplay broken pipe durante reprodução de silêncio.")
                        break
            
            try:
                aplay_proc.stdin.close()
            except Exception:
                pass
            aplay_proc.wait()
        else:
            logger.warning("aplay não encontrado — reproduzindo sequencialmente no terminal (sem áudio real).")
            for chunk in chunks:
                piper_proc = subprocess.Popen(
                    piper_cmd,
                    stdin=subprocess.PIPE,
                    stdout=subprocess.PIPE,
                    stderr=None,
                )
                piper_proc.communicate(input=chunk.encode("utf-8"))
                piper_proc.wait()
    except Exception as e:
        logger.error(f"TTS falhou no fluxo prosódico: {e}")
        _fallback_spd_say(text)

