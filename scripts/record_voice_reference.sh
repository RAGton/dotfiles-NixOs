#!/usr/bin/env bash
# =============================================================================
# record_voice_reference.sh — Grava referência de voz da Kora (PT-BR)
#
# Uso:
#   bash /etc/kryonix/scripts/record_voice_reference.sh
#
# O que faz:
#   1. Grava 5 frases PT-BR (5s cada) via arecord
#   2. Transcreve cada uma com whisper (fallback: Python/kora)
#   3. Concatena em kora.wav com 200ms silêncio entre frases
#   4. Reproduz o resultado para aprovação
#   5. Salva em /var/lib/f5-tts/voices/kora.wav + kora.txt
#
# Requisitos: arecord, aplay, python3
# Opcional:   whisper-cli (faster-whisper) para transcrição automática
# =============================================================================
set -euo pipefail

# ── Configuração ─────────────────────────────────────────────────────────────

VOICES_DIR="/var/lib/f5-tts/voices"
OUT_WAV="$VOICES_DIR/kora.wav"
OUT_TXT="$VOICES_DIR/kora.txt"
SAMPLE_RATE=22050
CHANNELS=1
FORMAT="S16_LE"
RECORD_SEC=5
SILENCE_MS=200

TMP_DIR=$(mktemp -d /tmp/kora-ref-XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

# Frases de referência PT-BR — naturalidade variada (afirmação, dúvida, ação, curiosidade, acolhimento)
PHRASES=(
    "Oi, eu sou a Kora, sua assistente pessoal."
    "Você tem certeza disso? Posso verificar pra você."
    "Pronto, já cuidei de tudo. Pode deixar comigo."
    "Hmm, isso é interessante. Deixa eu pensar um segundo."
    "Tá tudo bem, a gente resolve juntos."
)

# ── Funções ───────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[0;33m'
CYN='\033[0;36m'
RST='\033[0m'

info()  { echo -e "${CYN}[INFO]${RST} $*"; }
ok()    { echo -e "${GRN}[ OK ]${RST} $*"; }
warn()  { echo -e "${YLW}[WARN]${RST} $*"; }
error() { echo -e "${RED}[ERR ]${RST} $*" >&2; }
die()   { error "$*"; exit 1; }

check_deps() {
    command -v arecord &>/dev/null || die "arecord não encontrado (pacote alsa-utils)"
    command -v aplay   &>/dev/null || die "aplay não encontrado (pacote alsa-utils)"
    command -v python3 &>/dev/null || die "python3 não encontrado"
}

record_phrase() {
    local idx="$1"
    local phrase="$2"
    local outfile="$TMP_DIR/phrase_${idx}.wav"

    echo ""
    echo -e "${YLW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
    echo -e "  Frase $((idx+1))/${#PHRASES[@]}: ${CYN}${phrase}${RST}"
    echo -e "${YLW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
    echo ""
    echo "  Pressione ENTER para começar a gravar (${RECORD_SEC}s)..."
    read -r

    echo -e "  ${RED}● GRAVANDO...${RST} fale a frase agora"
    arecord -q \
        -f "$FORMAT" \
        -r "$SAMPLE_RATE" \
        -c "$CHANNELS" \
        -d "$RECORD_SEC" \
        "$outfile" 2>/dev/null

    echo -e "  ${GRN}■ Gravação concluída${RST}"
    echo -n "  Ouvir a gravação? [S/n] "
    read -r confirm
    if [[ "${confirm,,}" != "n" ]]; then
        aplay -q "$outfile" 2>/dev/null || warn "aplay falhou na reprodução"
    fi

    echo -n "  Gravar novamente? [s/N] "
    read -r redo
    if [[ "${redo,,}" == "s" ]]; then
        record_phrase "$idx" "$phrase"
        return
    fi

    echo "$outfile"
}

transcribe_phrase() {
    local wavfile="$1"
    local hint_text="$2"
    local result=""

    # Tentativa 1: whisper-cli (faster-whisper no PATH)
    if command -v whisper-cli &>/dev/null 2>&1; then
        result=$(whisper-cli --language pt --model base "$wavfile" 2>/dev/null | tail -1 | sed 's/\[.*\] //' | xargs) || result=""
    fi

    # Tentativa 2: faster-whisper via Python (kora STT)
    if [ -z "$result" ] && python3 -c "import faster_whisper" &>/dev/null 2>&1; then
        result=$(python3 - "$wavfile" <<'PYEOF' 2>/dev/null
import sys
from faster_whisper import WhisperModel
model = WhisperModel("base", device="auto", compute_type="auto")
segments, _ = model.transcribe(sys.argv[1], language="pt")
print(" ".join(s.text.strip() for s in segments))
PYEOF
        ) || result=""
    fi

    # Tentativa 3: whisper via kora (se disponível no PATH)
    if [ -z "$result" ] && command -v kora &>/dev/null 2>&1; then
        result=$(python3 -c "
from kora.voice.stt import transcribe_audio
print(transcribe_audio('${wavfile}'))
" 2>/dev/null) || result=""
    fi

    # Fallback: texto de referência original (hint)
    if [ -z "$result" ]; then
        warn "Transcrição automática falhou — usando texto de referência original"
        result="$hint_text"
    fi

    echo "$result"
}

generate_silence_wav() {
    # Gera um WAV com N milissegundos de silêncio (16-bit PCM mono)
    local ms="$1"
    local outfile="$2"
    local frames=$(( SAMPLE_RATE * ms / 1000 ))

    python3 - "$outfile" "$frames" "$SAMPLE_RATE" <<'PYEOF'
import sys, wave, struct
outfile, frames, rate = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
with wave.open(outfile, 'wb') as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(rate)
    w.writeframes(struct.pack('<' + 'h' * frames, *([0] * frames)))
PYEOF
}

concatenate_wavs() {
    # Concatena lista de WAVs com silêncio de separação
    # Args: outfile wav1 wav2 ... wavN
    local outfile="$1"
    shift
    local inputs=("$@")

    local silence_wav="$TMP_DIR/silence.wav"
    generate_silence_wav "$SILENCE_MS" "$silence_wav"

    python3 - "$outfile" "$silence_wav" "${inputs[@]}" <<'PYEOF'
import sys, wave

outfile = sys.argv[1]
silence_wav = sys.argv[2]
inputs = sys.argv[3:]

def read_frames(path):
    with wave.open(path, 'rb') as w:
        return w.getnchannels(), w.getsampwidth(), w.getframerate(), w.readframes(w.getnframes())

def read_silence(path):
    _, _, _, frames = read_frames(path)
    return frames

silence_frames = read_silence(silence_wav)
all_frames = []

for i, inp in enumerate(inputs):
    ch, sw, fr, frames = read_frames(inp)
    if i > 0:
        all_frames.append(silence_frames)
    all_frames.append(frames)

ref_ch, ref_sw, ref_fr, _ = read_frames(inputs[0])

with wave.open(outfile, 'wb') as out:
    out.setnchannels(ref_ch)
    out.setsampwidth(ref_sw)
    out.setframerate(ref_fr)
    for frames in all_frames:
        out.writeframes(frames)
PYEOF
}

# ── Main ──────────────────────────────────────────────────────────────────────

echo ""
echo -e "${CYN}╭─────────────────────────────────────────────────╮${RST}"
echo -e "${CYN}│   Kora Voice Reference Recorder                 │${RST}"
echo -e "${CYN}│   ${RST}Grava 5 frases PT-BR para clonagem zero-shot   ${CYN}│${RST}"
echo -e "${CYN}╰─────────────────────────────────────────────────╯${RST}"
echo ""

check_deps

# Garante diretório de saída
if [ "$(id -u)" = "0" ]; then
    mkdir -p "$VOICES_DIR"
    chown -R f5tts:f5tts "$VOICES_DIR" 2>/dev/null || true
else
    mkdir -p "$VOICES_DIR" 2>/dev/null || {
        warn "Sem permissão para criar $VOICES_DIR"
        warn "Execute como root ou ajuste permissões:"
        warn "  sudo mkdir -p $VOICES_DIR && sudo chown $USER:$USER $VOICES_DIR"
        VOICES_DIR="$TMP_DIR/output"
        OUT_WAV="$VOICES_DIR/kora.wav"
        OUT_TXT="$VOICES_DIR/kora.txt"
        mkdir -p "$VOICES_DIR"
        warn "Salvando em $VOICES_DIR (mova manualmente depois)"
    }
fi

# Detecta dispositivo de entrada disponível
info "Dispositivos de gravação disponíveis:"
arecord -l 2>/dev/null | grep -E "^card" | head -5 || warn "nenhum dispositivo listado"
echo ""

# Grava cada frase
declare -a recorded_files
declare -a transcriptions

for i in "${!PHRASES[@]}"; do
    phrase="${PHRASES[$i]}"
    wavfile=$(record_phrase "$i" "$phrase")
    recorded_files+=("$wavfile")

    info "Transcrevendo frase $((i+1))..."
    transcription=$(transcribe_phrase "$wavfile" "$phrase")
    transcriptions+=("$transcription")
    ok "Transcrição: $transcription"
done

# Concatena
info "Concatenando ${#recorded_files[@]} frases com ${SILENCE_MS}ms de silêncio..."
combined_wav="$TMP_DIR/kora_combined.wav"
concatenate_wavs "$combined_wav" "${recorded_files[@]}"
ok "Áudio combinado: $(du -h "$combined_wav" | cut -f1)"

# Duração total
total_sec=$(python3 -c "
import wave
with wave.open('$combined_wav', 'rb') as w:
    print(f'{w.getnframes() / w.getframerate():.1f}')
")
info "Duração total: ${total_sec}s"

# Reproduz para aprovação
echo ""
echo -e "  Reproduzindo áudio combinado para aprovação..."
aplay -q "$combined_wav" 2>/dev/null || warn "aplay falhou"

echo ""
echo -n "  Salvar como referência de voz da Kora? [S/n] "
read -r approve

if [[ "${approve,,}" == "n" ]]; then
    warn "Cancelado pelo usuário. Arquivos temporários em $TMP_DIR (não serão deletados)"
    trap - EXIT
    info "Para regravar, execute o script novamente."
    exit 0
fi

# Salva
cp "$combined_wav" "$OUT_WAV"

# Gera kora.txt com transcrições concatenadas
{
    for t in "${transcriptions[@]}"; do
        echo -n "$t "
    done
} | xargs > "$OUT_TXT"

ok "Salvo: $OUT_WAV"
ok "Salvo: $OUT_TXT"

# Corrige permissões se root
if [ "$(id -u)" = "0" ]; then
    chown f5tts:f5tts "$OUT_WAV" "$OUT_TXT" 2>/dev/null || true
fi

echo ""
echo -e "${GRN}╭──────────────────────────────────────────────────╮${RST}"
echo -e "${GRN}│  ✓ Referência de voz gravada com sucesso!        │${RST}"
echo -e "${GRN}╰──────────────────────────────────────────────────╯${RST}"
echo ""
echo "  Próximos passos:"
echo "    systemctl start f5-tts-server"
echo "    curl http://localhost:7860/health"
echo "    curl -s -X POST http://localhost:7860/synthesize \\"
echo "      -H 'Content-Type: application/json' \\"
echo "      -d '{\"text\":\"Olá, estou funcionando.\"}' \\"
echo "      --output /tmp/test.wav && aplay /tmp/test.wav"
