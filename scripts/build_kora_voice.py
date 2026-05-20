#!/usr/bin/env python3
"""
build_kora_voice.py — Gera kora.wav a partir do Mozilla Common Voice PT.

Filtra amostras femininas de qualidade, concatena em um WAV de referência
para o F5-TTS e copia para o glacier (onde o servidor F5-TTS roda).

Uso:
    python3 scripts/build_kora_voice.py [--seed 42] [--min-secs 25] [--max-secs 35]
    nix shell nixpkgs#ffmpeg -c python3 scripts/build_kora_voice.py
"""

import argparse
import csv
import random
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

csv.field_size_limit(sys.maxsize)

# ─── constantes ────────────────────────────────────────────────────────────────

DATASET_DIR = Path("/home/rocha/Documents/voz/cv-corpus-25.0-2026-03-09/pt")
VALIDATED_TSV = DATASET_DIR / "validated.tsv"
DURATIONS_TSV = DATASET_DIR / "clip_durations.tsv"
CLIPS_DIR = DATASET_DIR / "clips"

DEFAULT_OUT = Path("/var/lib/f5-tts/voices/kora.wav")
FALLBACK_OUT = Path("/tmp/kora-voice/kora.wav")

SILENCE_MS = 150
SAMPLE_RATE = 22050
GENDER_FIELD = "female_feminine"


# ─── helpers ───────────────────────────────────────────────────────────────────

def find_ffmpeg() -> str:
    candidates = [
        shutil.which("ffmpeg"),
        "/run/current-system/sw/bin/ffmpeg",
        "/usr/bin/ffmpeg",
    ]
    for c in candidates:
        if c and Path(c).exists():
            return c
    print("ERRO: ffmpeg não encontrado.")
    print("Execute com: nix shell nixpkgs#ffmpeg -c python3 scripts/build_kora_voice.py")
    sys.exit(1)


def load_durations(tsv: Path) -> dict[str, int]:
    """Retorna {clip_filename: duration_ms}."""
    durations: dict[str, int] = {}
    with open(tsv, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            clip = row.get("clip", "").strip()
            try:
                durations[clip] = int(row["duration[ms]"])
            except (KeyError, ValueError):
                pass
    return durations


def load_candidates(tsv: Path, durations: dict[str, int],
                    require_upvotes: bool = True) -> list[dict]:
    candidates = []
    with open(tsv, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f, delimiter="\t")
        if "gender" not in (reader.fieldnames or []):
            print("ERRO: coluna 'gender' não encontrada no TSV.")
            print(f"Colunas disponíveis: {reader.fieldnames}")
            sys.exit(1)
        for row in reader:
            if row.get("gender", "").strip() != GENDER_FIELD:
                continue
            try:
                down = int(row.get("down_votes", "0") or "0")
                up = int(row.get("up_votes", "0") or "0")
            except ValueError:
                continue
            if down != 0:
                continue
            if require_upvotes and up < 1:
                continue
            clip = row.get("path", "").strip()
            dur = durations.get(clip, 0)
            if not (2000 <= dur <= 8000):
                continue
            if not clip or not row.get("sentence", "").strip():
                continue
            candidates.append({
                "clip": clip,
                "sentence": row["sentence"].strip(),
                "duration_ms": dur,
                "up_votes": up,
            })
    return candidates


def convert_to_wav(ffmpeg: str, src: Path, dst: Path) -> bool:
    result = subprocess.run(
        [ffmpeg, "-y", "-i", str(src),
         "-ar", str(SAMPLE_RATE), "-ac", "1", "-sample_fmt", "s16",
         "-f", "wav", str(dst)],
        capture_output=True, text=True,
    )
    return result.returncode == 0


def make_silence(ffmpeg: str, dst: Path, ms: int) -> None:
    secs = ms / 1000.0
    subprocess.run(
        [ffmpeg, "-y", "-f", "lavfi",
         "-i", f"anullsrc=r={SAMPLE_RATE}:cl=mono",
         "-t", str(secs), "-f", "wav", str(dst)],
        capture_output=True, check=True,
    )


def concat_wavs(ffmpeg: str, wav_files: list[Path], out: Path) -> None:
    list_file = Path(tempfile.mktemp(suffix="_filelist.txt"))
    with open(list_file, "w") as f:
        for w in wav_files:
            f.write(f"file '{w}'\n")
    subprocess.run(
        [ffmpeg, "-y", "-f", "concat", "-safe", "0",
         "-i", str(list_file),
         "-ar", str(SAMPLE_RATE), "-ac", "1",
         str(out)],
        capture_output=True, check=True,
    )
    list_file.unlink(missing_ok=True)


def copy_to_glacier(local_wav: Path, local_txt: Path) -> None:
    dest_dir = "rocha@rve-glacier:/var/lib/f5-tts/voices"
    print(f"\nCopiando para glacier ({dest_dir})...")

    # garante diretório com permissão correta no glacier
    subprocess.run(
        ["ssh", "rve-glacier",
         "sudo mkdir -p /var/lib/f5-tts/voices && sudo chown f5tts:f5tts /var/lib/f5-tts/voices"],
        capture_output=True,
    )

    # copia WAV
    r = subprocess.run(
        ["scp", str(local_wav), "rocha@rve-glacier:/tmp/kora.wav"],
        capture_output=True, text=True,
    )
    if r.returncode == 0:
        subprocess.run(
            ["ssh", "rve-glacier",
             "sudo mv /tmp/kora.wav /var/lib/f5-tts/voices/kora.wav "
             "&& sudo chown f5tts:f5tts /var/lib/f5-tts/voices/kora.wav"],
            capture_output=True,
        )
        print("kora.wav copiado para glacier com sucesso.")
    else:
        print(f"AVISO: falha ao copiar kora.wav: {r.stderr.strip()}")
        print(f"Copie manualmente: scp {local_wav} rocha@rve-glacier:/tmp/kora.wav")

    # copia TXT
    r = subprocess.run(
        ["scp", str(local_txt), "rocha@rve-glacier:/tmp/kora.txt"],
        capture_output=True, text=True,
    )
    if r.returncode == 0:
        subprocess.run(
            ["ssh", "rve-glacier",
             "sudo mv /tmp/kora.txt /var/lib/f5-tts/voices/kora.txt "
             "&& sudo chown f5tts:f5tts /var/lib/f5-tts/voices/kora.txt"],
            capture_output=True,
        )
        print("kora.txt copiado para glacier com sucesso.")
    else:
        print(f"AVISO: falha ao copiar kora.txt: {r.stderr.strip()}")


# ─── main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="Gera kora.wav a partir do Common Voice PT")
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--min-secs", type=float, default=25.0)
    parser.add_argument("--max-secs", type=float, default=35.0)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--no-upload", action="store_true",
                        help="Não copiar para glacier")
    args = parser.parse_args()

    ffmpeg = find_ffmpeg()
    print(f"ffmpeg: {ffmpeg}")

    # ── determinar destino ────────────────────────────────────────────────────
    out_wav = args.out
    try:
        out_wav.parent.mkdir(parents=True, exist_ok=True)
    except PermissionError:
        print(f"Sem permissão em {out_wav.parent}, usando {FALLBACK_OUT.parent}")
        out_wav = FALLBACK_OUT
        out_wav.parent.mkdir(parents=True, exist_ok=True)
    out_txt = out_wav.with_suffix(".txt")

    # ── carregar dados ────────────────────────────────────────────────────────
    print("Carregando clip_durations.tsv...")
    durations = load_durations(DURATIONS_TSV)
    print(f"  {len(durations)} durações carregadas")

    print("Filtrando amostras femininas (up_votes >= 1, down_votes == 0, 2–8s)...")
    candidates = load_candidates(VALIDATED_TSV, durations, require_upvotes=True)
    print(f"  {len(candidates)} candidatas encontradas")

    if len(candidates) < 5:
        print("  < 5 amostras — relaxando requisito de up_votes...")
        candidates = load_candidates(VALIDATED_TSV, durations, require_upvotes=False)
        print(f"  {len(candidates)} candidatas (sem filtro up_votes)")

    if not candidates:
        print("ERRO: nenhuma amostra feminina encontrada no dataset.")
        sys.exit(1)

    # ── selecionar amostras ───────────────────────────────────────────────────
    random.seed(args.seed)
    random.shuffle(candidates)

    selected = []
    total_ms = 0
    target_ms = args.max_secs * 1000
    for row in candidates:
        if total_ms >= args.min_secs * 1000:
            break
        if total_ms + row["duration_ms"] > target_ms:
            continue
        selected.append(row)
        total_ms += row["duration_ms"]

    print(f"\n{len(selected)} amostras selecionadas — {total_ms/1000:.1f}s de áudio")

    # ── converter e concatenar ────────────────────────────────────────────────
    tmpdir = Path(tempfile.mkdtemp(prefix="kora_voice_"))
    try:
        silence_wav = tmpdir / "silence.wav"
        make_silence(ffmpeg, silence_wav, SILENCE_MS)

        wav_sequence: list[Path] = []
        for i, row in enumerate(selected, 1):
            src_mp3 = CLIPS_DIR / row["clip"]
            dst_wav = tmpdir / f"sample_{i:03d}.wav"
            print(f"  [{i}/{len(selected)}] {row['clip']} ({row['duration_ms']}ms) — {row['sentence'][:60]}")
            if not convert_to_wav(ffmpeg, src_mp3, dst_wav):
                print(f"    AVISO: falha ao converter {src_mp3}, pulando")
                continue
            if wav_sequence:
                wav_sequence.append(silence_wav)
            wav_sequence.append(dst_wav)

        if not wav_sequence:
            print("ERRO: nenhum WAV convertido com sucesso.")
            sys.exit(1)

        print(f"\nConcatenando {len([w for w in wav_sequence if 'silence' not in w.name])} amostras...")
        concat_wavs(ffmpeg, wav_sequence, out_wav)

    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)

    # ── salvar transcrição ────────────────────────────────────────────────────
    transcript = " ".join(row["sentence"] for row in selected)
    out_txt.write_text(transcript, encoding="utf-8")

    # ── resumo ────────────────────────────────────────────────────────────────
    print(f"\n{'─'*60}")
    print(f"kora.wav  → {out_wav}")
    print(f"kora.txt  → {out_txt}")
    print(f"Amostras  : {len(selected)}")
    print(f"Duração   : {total_ms/1000:.1f}s")
    print(f"Textos    :")
    for row in selected:
        print(f"  • {row['sentence']}")
    print(f"{'─'*60}")

    # ── copiar para glacier ───────────────────────────────────────────────────
    if not args.no_upload:
        copy_to_glacier(out_wav, out_txt)
    else:
        print("\n--no-upload: pulando cópia para glacier.")


if __name__ == "__main__":
    main()
