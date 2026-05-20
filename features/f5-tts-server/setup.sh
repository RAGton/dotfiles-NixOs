#!/usr/bin/env bash
# =============================================================================
# F5-TTS Bootstrap — cria venv, instala PyTorch+CUDA e pré-baixa o modelo base
#
# Uso:   sudo bash /etc/kryonix/features/f5-tts-server/setup.sh
# Re-run seguro: idempotente (sai cedo se já completo)
# Forçar: setup.sh --force
# =============================================================================
set -euo pipefail

DATA_DIR="/var/lib/f5-tts"
VENV="$DATA_DIR/venv"
SENTINEL="$DATA_DIR/.setup_complete"
FORCE=0

[ "${1:-}" = "--force" ] && FORCE=1

# ── idempotência ─────────────────────────────────────────────────────────────
if [ -f "$SENTINEL" ] && [ "$FORCE" = "0" ]; then
    echo "F5-TTS já configurado ($SENTINEL). Use --force para refazer."
    exit 0
fi

# ── pré-requisitos ────────────────────────────────────────────────────────────

# Localiza python3.11: PATH → nix-build → erro
PYTHON311=""
if command -v python3.11 &>/dev/null; then
    PYTHON311=$(command -v python3.11)
elif command -v nix-build &>/dev/null; then
    echo "python3.11 não no PATH — localizando via nix-build (pode demorar)..."
    _nixout=$(nix-build --no-out-link '<nixpkgs>' -A python311 2>/dev/null) || true
    if [ -x "${_nixout:-}/bin/python3.11" ]; then
        PYTHON311="${_nixout}/bin/python3.11"
    fi
fi

if [ -z "$PYTHON311" ]; then
    echo "ERRO: python3.11 não encontrado."
    echo "  Execute: nix-shell -p python311 -- sudo bash $0"
    exit 1
fi

GPU_FREE=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ' || echo "0")
if [ "$GPU_FREE" -lt 3000 ] 2>/dev/null; then
    echo "AVISO: VRAM disponível: ${GPU_FREE} MiB (mínimo recomendado: 3000 MiB)"
    echo "       O modelo pode não carregar. Feche outros processos GPU."
fi

echo ""
echo "════════════════════════════════════════"
echo "  F5-TTS Bootstrap — glacier"
echo "  Python:  $($PYTHON311 --version)"
echo "  VRAM:    ${GPU_FREE} MiB livres"
echo "════════════════════════════════════════"
echo ""

# ── diretórios ────────────────────────────────────────────────────────────────
mkdir -p "$DATA_DIR"/{venv,models,voices,hf-cache}

# ── venv ─────────────────────────────────────────────────────────────────────
echo "[1/4] Criando venv Python 3.11..."
"$PYTHON311" -m venv "$VENV" --clear
"$VENV/bin/pip" install -q --upgrade pip wheel

# ── PyTorch CUDA 12.1 ────────────────────────────────────────────────────────
echo "[2/4] Instalando PyTorch + CUDA 12.4 (~2.5 GB, pode demorar)..."
"$VENV/bin/pip" install -q \
    torch torchaudio \
    --index-url https://download.pytorch.org/whl/cu124

# ── F5-TTS + servidor ────────────────────────────────────────────────────────
echo "[3/4] Instalando F5-TTS, FastAPI, uvicorn, soundfile..."
"$VENV/bin/pip" install -q f5-tts fastapi uvicorn soundfile

# ── pré-download do modelo base ───────────────────────────────────────────────
echo "[4/4] Pré-baixando F5-TTS base model de HuggingFace (~1.3 GB)..."
HF_HOME="$DATA_DIR/hf-cache" \
"$VENV/bin/python" - << 'PYEOF'
import sys

print("  Carregando F5TTS (baixa checkpoint na primeira execução)...")
try:
    from f5_tts.api import F5TTS
    tts = F5TTS(model_type="F5-TTS")
    del tts
    print("  Modelo F5-TTS base: OK")
except Exception as e:
    print(f"  AVISO: {e}", file=sys.stderr)
    print("  O modelo será baixado na primeira requisição de síntese.")
PYEOF

# ── permissões ────────────────────────────────────────────────────────────────
if [ "$(id -u)" = "0" ]; then
    chown -R f5tts:f5tts "$DATA_DIR" 2>/dev/null || true
fi

touch "$SENTINEL"
echo ""
echo "✓ Setup completo!"
echo ""
echo "Próximos passos:"
echo "  1. Gravar referência:  bash /etc/kryonix/scripts/record_voice_reference.sh"
echo "  2. Iniciar servidor:   systemctl start f5-tts-server"
echo "  3. Testar:             curl -s http://localhost:7860/health"
