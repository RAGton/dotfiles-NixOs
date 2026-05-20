# =============================================================================
# Kora Voice — Models Manager
# =============================================================================
# Gerencia download e instalação local de modelos Whisper (STT) e Piper (TTS).
# Modelos ficam em /var/lib/kryonix/kora/voice/models/{whisper,piper}.
# Symlinks current.bin / current.onnx apontam para o modelo ativo.
# =============================================================================

import os
import sys
import shutil
import logging
import hashlib
from pathlib import Path
from urllib.request import urlopen, Request
from urllib.error import URLError, HTTPError

logger = logging.getLogger("kora.voice.models")

# ---------------------------------------------------------------------------
# Diretórios canônicos
# ---------------------------------------------------------------------------
MODELS_BASE = Path("/var/lib/kryonix/kora/voice/models")
WHISPER_DIR = MODELS_BASE / "whisper"
PIPER_DIR   = MODELS_BASE / "piper"

# ---------------------------------------------------------------------------
# Catálogo Whisper (ggerganov/whisper.cpp @ HuggingFace)
# ---------------------------------------------------------------------------
HF_WHISPER_BASE = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main"

WHISPER_MODELS = {
    "tiny":  {"file": "ggml-tiny.bin",  "size_mb": 75},
    "base":  {"file": "ggml-base.bin",  "size_mb": 148},
    "small": {"file": "ggml-small.bin", "size_mb": 488},
}

# ---------------------------------------------------------------------------
# Catálogo Piper PT-BR (rhasspy/piper-voices @ HuggingFace)
# ---------------------------------------------------------------------------
HF_PIPER_BASE = "https://huggingface.co/rhasspy/piper-voices/resolve/main"

PIPER_VOICES = {
    "edresson": {
        "model":  "pt/pt_BR/edresson/low/pt_BR-edresson-low.onnx",
        "config": "pt/pt_BR/edresson/low/pt_BR-edresson-low.onnx.json",
        "local_model":  "pt_BR-edresson-low.onnx",
        "local_config": "pt_BR-edresson-low.onnx.json",
    },
    "faber": {
        "model":  "pt/pt_BR/faber/medium/pt_BR-faber-medium.onnx",
        "config": "pt/pt_BR/faber/medium/pt_BR-faber-medium.onnx.json",
        "local_model":  "pt_BR-faber-medium.onnx",
        "local_config": "pt_BR-faber-medium.onnx.json",
    },
    "cadu": {
        "model":  "pt/pt_BR/cadu/medium/pt_BR-cadu-medium.onnx",
        "config": "pt/pt_BR/cadu/medium/pt_BR-cadu-medium.onnx.json",
        "local_model":  "pt_BR-cadu-medium.onnx",
        "local_config": "pt_BR-cadu-medium.onnx.json",
    },
    "jeff": {
        "model":  "pt/pt_BR/jeff/medium/pt_BR-jeff-medium.onnx",
        "config": "pt/pt_BR/jeff/medium/pt_BR-jeff-medium.onnx.json",
        "local_model":  "pt_BR-jeff-medium.onnx",
        "local_config": "pt_BR-jeff-medium.onnx.json",
    },
    "kora_ptbr_female": {
        "model":        "dii_pt-BR.onnx",
        "config":       "dii_pt-BR.onnx.json",
        "local_model":  "dii_pt-BR.onnx",
        "local_config": "dii_pt-BR.onnx.json",
        "url_base":     "https://huggingface.co/OpenVoiceOS/pipertts_pt-BR_dii/resolve/main",
    },
    "kora_sage": {
        "model":        "pt_BR-sage_13364-medium.onnx",
        "config":       "pt_BR-sage_13364-medium.onnx.json",
        "local_model":  "pt_BR-sage_13364-medium.onnx",
        "local_config": "pt_BR-sage_13364-medium.onnx.json",
        "url_base":     "https://huggingface.co/srxz/sage-voice-pt-br/resolve/main",
    },
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def _download_file(url: str, dest: Path, expected_mb: float | None = None) -> None:
    """Download url → dest com barra de progresso simples."""
    print(f"  ↓ Baixando {dest.name}...")
    tmp = dest.with_suffix(dest.suffix + ".tmp")
    try:
        req = Request(url, headers={"User-Agent": "kora-models/1.0"})
        with urlopen(req, timeout=120) as response:
            total = int(response.headers.get("Content-Length", 0))
            downloaded = 0
            chunk = 65536
            with open(tmp, "wb") as f:
                while True:
                    data = response.read(chunk)
                    if not data:
                        break
                    f.write(data)
                    downloaded += len(data)
                    if total:
                        pct = downloaded * 100 // total
                        mb = downloaded / 1_048_576
                        print(f"\r    {pct:3d}%  {mb:.1f} MB", end="", flush=True)
            print()
        tmp.rename(dest)
        dest.chmod(0o640)
        logger.info(f"Download concluído: {dest}")
    except (URLError, HTTPError) as e:
        tmp.unlink(missing_ok=True)
        raise RuntimeError(f"Falha no download de {url}: {e}") from e


def _set_symlink(link: Path, target_name: str) -> None:
    """Aponta symlink link → target_name (basename no mesmo diretório)."""
    if link.is_symlink() or link.exists():
        link.unlink()
    link.symlink_to(target_name)


# ---------------------------------------------------------------------------
# Resolução de modelo ativo
# ---------------------------------------------------------------------------

def resolve_whisper_model() -> Path | None:
    """Retorna o caminho do modelo Whisper ativo, ou None se não encontrado."""
    candidates = [
        os.environ.get("KORA_WHISPER_MODEL"),
        str(WHISPER_DIR / "current.bin"),
        str(WHISPER_DIR / "ggml-base.bin"),
    ]
    for c in candidates:
        if c:
            p = Path(c).resolve()
            if p.exists() and p.stat().st_size > 1_000_000:
                return p
    return None


def resolve_piper_model() -> tuple[Path | None, Path | None]:
    """Retorna (model_path, config_path) do modelo Piper ativo, ou (None, None)."""
    model_candidates = [
        os.environ.get("KORA_PIPER_MODEL"),
        str(PIPER_DIR / "current.onnx"),
        str(PIPER_DIR / "pt_BR-edresson-low.onnx"),
        str(PIPER_DIR / "pt_BR-faber-medium.onnx"),
        str(PIPER_DIR / "pt_BR-cadu-medium.onnx"),
    ]
    config_candidates = [
        os.environ.get("KORA_PIPER_CONFIG"),
        str(PIPER_DIR / "current.onnx.json"),
        str(PIPER_DIR / "pt_BR-edresson-low.onnx.json"),
        str(PIPER_DIR / "pt_BR-faber-medium.onnx.json"),
        str(PIPER_DIR / "pt_BR-cadu-medium.onnx.json"),
    ]
    model = None
    for c in model_candidates:
        if c:
            p = Path(c).resolve()
            if p.exists() and p.stat().st_size > 1_000:
                model = p
                break
    config = None
    for c in config_candidates:
        if c:
            p = Path(c).resolve()
            if p.exists():
                config = p
                break
    return model, config


# ---------------------------------------------------------------------------
# CLI actions
# ---------------------------------------------------------------------------

def cmd_status() -> None:
    """Imprime status JSON dos modelos ativos."""
    import json

    whisper = resolve_whisper_model()
    piper_model, piper_config = resolve_piper_model()

    # Detectar nome do modelo whisper ativo
    if whisper:
        for name, meta in WHISPER_MODELS.items():
            if meta["file"] in whisper.name:
                whisper_name = name
                break
        else:
            whisper_name = whisper.name
    else:
        whisper_name = None

    # Detectar nome da voz piper ativa
    if piper_model:
        for name, meta in PIPER_VOICES.items():
            if meta["local_model"] in piper_model.name:
                piper_name = name
                break
        else:
            piper_name = piper_model.name
    else:
        piper_name = None

    status = {
        "whisper": {
            "selected": whisper_name,
            "path": str(whisper) if whisper else None,
            "exists": whisper is not None,
            "size_mb": round(whisper.stat().st_size / 1_048_576, 1) if whisper else 0,
        },
        "piper": {
            "selected": piper_name,
            "model": str(piper_model) if piper_model else None,
            "config": str(piper_config) if piper_config else None,
            "exists": piper_model is not None and piper_config is not None,
        },
    }
    print(json.dumps(status, indent=2, ensure_ascii=False))


def cmd_list() -> None:
    """Lista modelos disponíveis para instalação."""
    print("\n[MODELOS WHISPER disponíveis]")
    for name, meta in WHISPER_MODELS.items():
        installed = (WHISPER_DIR / meta["file"]).exists()
        flag = "✓" if installed else " "
        print(f"  {flag} {name:<8}  {meta['size_mb']:>4} MB  — {meta['file']}")

    print("\n[MODELOS PIPER PT-BR disponíveis]")
    for name, meta in PIPER_VOICES.items():
        installed = (PIPER_DIR / meta["local_model"]).exists()
        flag = "✓" if installed else " "
        print(f"  {flag} {name:<8}  — {meta['local_model']}")
    print()


def cmd_install_whisper(model_name: str) -> None:
    """Instala modelo Whisper e atualiza symlink current.bin."""
    if model_name not in WHISPER_MODELS:
        print(f"[ERRO] Modelo desconhecido: '{model_name}'. Disponíveis: {list(WHISPER_MODELS)}")
        sys.exit(1)

    meta = WHISPER_MODELS[model_name]
    _ensure_dir(WHISPER_DIR)

    dest = WHISPER_DIR / meta["file"]
    if dest.exists() and dest.stat().st_size > 1_000_000:
        print(f"  ✓ Modelo já instalado: {dest}")
    else:
        url = f"{HF_WHISPER_BASE}/{meta['file']}"
        _download_file(url, dest, expected_mb=meta["size_mb"])

    # Symlink current.bin
    _set_symlink(WHISPER_DIR / "current.bin", meta["file"])
    print(f"  ✓ Ativo: {dest}")
    print(f"  ✓ Symlink: {WHISPER_DIR / 'current.bin'} → {meta['file']}")


def cmd_install_piper(voice_name: str) -> None:
    """Instala voz Piper e atualiza symlinks current.onnx / current.onnx.json."""
    if voice_name not in PIPER_VOICES:
        print(f"[ERRO] Voz desconhecida: '{voice_name}'. Disponíveis: {list(PIPER_VOICES)}")
        sys.exit(1)

    meta = PIPER_VOICES[voice_name]
    _ensure_dir(PIPER_DIR)

    model_dest  = PIPER_DIR / meta["local_model"]
    config_dest = PIPER_DIR / meta["local_config"]

    url_base = meta.get("url_base", HF_PIPER_BASE)

    if model_dest.exists() and model_dest.stat().st_size > 1_000:
        print(f"  ✓ Modelo já instalado: {model_dest}")
    else:
        _download_file(f"{url_base}/{meta['model']}", model_dest)

    if config_dest.exists():
        print(f"  ✓ Config já instalada: {config_dest}")
    else:
        _download_file(f"{url_base}/{meta['config']}", config_dest)

    _set_symlink(PIPER_DIR / "current.onnx",      meta["local_model"])
    _set_symlink(PIPER_DIR / "current.onnx.json", meta["local_config"])
    print(f"  ✓ Voz ativa: {voice_name}")


def cmd_import_piper(voice_name: str, model_path: str, config_path: str) -> None:
    """Importa modelo Piper custom de caminho local."""
    import json
    import time

    src_model = Path(model_path)
    src_config = Path(config_path)

    if not src_model.exists():
        print(f"[ERRO] Modelo não encontrado: {src_model}")
        sys.exit(1)
    if not src_config.exists():
        print(f"[ERRO] Config não encontrada: {src_config}")
        sys.exit(1)

    dest_dir = PIPER_DIR / voice_name
    _ensure_dir(dest_dir)

    dest_model = dest_dir / "model.onnx"
    dest_config = dest_dir / "model.onnx.json"
    dest_meta = dest_dir / "metadata.json"

    print(f"  → Importando voz '{voice_name}' para {dest_dir}...")
    shutil.copy2(src_model, dest_model)
    dest_model.chmod(0o640)
    shutil.copy2(src_config, dest_config)
    dest_config.chmod(0o640)

    # Metadata
    metadata = {
        "name": voice_name,
        "source": str(src_model),
        "imported_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "type": "custom_import",
    }
    dest_meta.write_text(json.dumps(metadata, indent=2, ensure_ascii=False))

    # Update symlinks to point to this model
    _set_symlink(PIPER_DIR / "current.onnx", f"{voice_name}/model.onnx")
    _set_symlink(PIPER_DIR / "current.onnx.json", f"{voice_name}/model.onnx.json")

    print(f"  ✓ Voz importada: {voice_name}")
    print(f"  ✓ Symlink ativo: current.onnx → {voice_name}/model.onnx")
    print(f"  ✓ Para usar: kora voice voices set kora_ptbr_female")

