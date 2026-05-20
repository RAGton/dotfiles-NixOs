#!/usr/bin/env python3
"""
build_kora_voice.py — Gera kora.wav a partir do Mozilla Common Voice PT.

Filtra amostras femininas de qualidade, concatena em WAV de referência
para o F5-TTS e copia para o glacier (onde o servidor F5-TTS roda).

Uso:
    python3 scripts/build_kora_voice.py [--seed 42] [--min-secs 25] [--max-secs 35]
    python3 scripts/build_kora_voice.py --no-upload   # sem deploy para glacier
"""

import argparse
import csv
import random
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# client_id do Common Voice tem hashes SHA-512 que excedem o limite padrão
csv.field_size_limit(sys.maxsize)

# ─── constantes ────────────────────────────────────────────────────────────────

DATASET_DIR  = Path("/home/rocha/Documents/voz/cv-corpus-25.0-2026-03-09/pt")
VALIDATED    = DATASET_DIR / "validated.tsv"
DURATIONS    = DATASET_DIR / "clip_durations.tsv"
CLIPS_DIR    = DATASET_DIR / "clips"

DEFAULT_OUT  = Path("/var/lib/f5-tts/voices/kora.wav")
FALLBACK_OUT = Path("/tmp/kora-voice/kora.wav")

SAMPLE_RATE  = 22050
SILENCE_SECS = 0.15
GENDER_VALUE = "female_feminine"


# ─── ffmpeg ────────────────────────────────────────────────────────────────────

def find_ffmpeg() -> str:
    found = shutil.which("ffmpeg") or (
        "/run/current-system/sw/bin/ffmpeg"
        if Path("/run/current-system/sw/bin/ffmpeg").exists()
        else None
    )
    if not found:
        print("ERRO: ffmpeg não encontrado.")
        print("Execute com: nix shell nixpkgs#ffmpeg -c python3 scripts/build_kora_voice.py")
        sys.exit(1)
    return found


# ─── dataset ───────────────────────────────────────────────────────────────────

def load_durations() -> dict[str, int]:
    durations: dict[str, int] = {}
    with open(DURATIONS, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f, delimiter="\t"):
            clip = row.get("clip", "").strip()
            try:
                durations[clip] = int(row["duration[ms]"])
            except (KeyError, ValueError):
                pass
    return durations


def load_candidates(durations: dict[str, int], require_upvotes: bool = True) -> list[dict]:
    candidates = []
    with open(VALIDATED, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f, delimiter="\t")
        if "gender" not in (reader.fieldnames or []):
            print("ERRO: coluna 'gender' não encontrada.")
            print(f"Colunas: {reader.fieldnames}")
            sys.exit(1)
        for row in reader:
            if row.get("gender", "").strip() != GENDER_VALUE:
                continue
            try:
                down = int(row.get("down_votes") or 0)
                up   = int(row.get("up_votes")   or 0)
            except ValueError:
                continue
            if down != 0:
                continue
            if require_upvotes and up < 1:
                continue
            clip = row.get("path", "").strip()
            dur  = durations.get(clip, 0)
            if not (2000 <= dur <= 8000):
                continue
            sentence = row.get("sentence", "").strip()
            if not clip or not sentence:
                continue
            candidates.append({"clip": clip, "sentence": sentence, "duration_ms": dur})
    return candidates


# ─── áudio ─────────────────────────────────────────────────────────────────────

def convert_mp3(ffmpeg: str, src: Path, dst: Path) -> bool:
    r = subprocess.run(
        [ffmpeg, "-y", "-i", str(src),
         "-ar", str(SAMPLE_RATE), "-ac", "1", "-sample_fmt", "s16",
         "-f", "wav", str(dst)],
        capture_output=True,
    )
    return r.returncode == 0


def make_silence(ffmpeg: str, dst: Path) -> None:
    subprocess.run(
        [ffmpeg, "-y", "-f", "lavfi",
         "-i", f"anullsrc=r={SAMPLE_RATE}:cl=mono",
         "-t", str(SILENCE_SECS), "-f", "wav", str(dst)],
        capture_output=True, check=True,
    )


def concat(ffmpeg: str, wav_files: list[Path], list_file: Path, out: Path) -> None:
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


# ─── deploy ────────────────────────────────────────────────────────────────────

def deploy_to_glacier(wav: Path, txt: Path) -> None:
    dest = "rocha@rve-glacier"
    dest_dir = "/var/lib/f5-tts/voices"
    print(f"\nDeploy → glacier:{dest_dir}")

    subprocess.run(
        ["ssh", "rve-glacier",
         f"sudo mkdir -p {dest_dir} && sudo chown f5tts:f5tts {dest_dir}"],
        capture_output=True,
    )

    for local, remote_tmp, final_name in [
        (wav, "/tmp/kora.wav", "kora.wav"),
        (txt, "/tmp/kora.txt", "kora.txt"),
    ]:
        r = subprocess.run(
            ["scp", str(local), f"{dest}:{remote_tmp}"],
            capture_output=True, text=True,
        )
        if r.returncode == 0:
            subprocess.run(
                ["ssh", "rve-glacier",
                 f"sudo mv {remote_tmp} {dest_dir}/{final_name} "
                 f"&& sudo chown f5tts:f5tts {dest_dir}/{final_name}"],
                capture_output=True,
            )
            print(f"  {final_name} — ok")
        else:
            print(f"  AVISO: falha ao enviar {local.name}: {r.stderr.strip()}")
            print(f"  Copie manualmente: scp {local} {dest}:{remote_tmp}")


# ─── main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    ap = argparse.ArgumentParser(description="Gera kora.wav a partir do Common Voice PT")
    ap.add_argument("--seed",      type=int,   default=42)
    ap.add_argument("--min-secs",  type=float, default=25.0)
    ap.add_argument("--max-secs",  type=float, default=35.0)
    ap.add_argument("--out",       type=Path,  default=DEFAULT_OUT)
    ap.add_argument("--no-upload", action="store_true", help="Pula o scp/ssh para glacier")
    args = ap.parse_args()

    ffmpeg = find_ffmpeg()
    print(f"ffmpeg: {ffmpeg}\n")

    # ── destino final ─────────────────────────────────────────────────────────
    out_wav = args.out
    out_dir = out_wav.parent
    try:
        out_dir.mkdir(parents=True, exist_ok=True)
        probe = out_dir / ".write_probe"
        probe.touch()
        probe.unlink()
    except PermissionError:
        out_dir = Path("/tmp/kora-voice")
        out_dir.mkdir(parents=True, exist_ok=True)
        out_wav = out_dir / "kora.wav"
        print(f"AVISO: sem permissão em {args.out.parent} — salvando em {out_dir}\n")
    out_txt = out_wav.with_suffix(".txt")

    # ── dataset ───────────────────────────────────────────────────────────────
    print("Carregando clip_durations.tsv...")
    durations = load_durations()
    print(f"  {len(durations):,} entradas\n")

    print("Filtrando amostras (female_feminine, down_votes=0, up_votes≥1, 2–8s)...")
    candidates = load_candidates(durations, require_upvotes=True)
    print(f"  {len(candidates):,} candidatas")
    if len(candidates) < 5:
        print("  < 5 amostras — relaxando up_votes...")
        candidates = load_candidates(durations, require_upvotes=False)
        print(f"  {len(candidates):,} candidatas (sem filtro up_votes)")

    if not candidates:
        print("ERRO: nenhuma amostra feminina encontrada.")
        sys.exit(1)

    # ── seleção ───────────────────────────────────────────────────────────────
    random.seed(args.seed)
    random.shuffle(candidates)

    selected: list[dict] = []
    total_ms = 0
    for row in candidates:
        if total_ms >= args.min_secs * 1000:
            break
        if total_ms + row["duration_ms"] > args.max_secs * 1000:
            continue
        selected.append(row)
        total_ms += row["duration_ms"]

    print(f"\n{len(selected)} amostras selecionadas — {total_ms / 1000:.1f}s\n")

    # ── processamento (tudo em tmpdir) ────────────────────────────────────────
    tmpdir = Path(tempfile.mkdtemp(prefix="kora_voice_"))
    try:
        silence = tmpdir / "silence.wav"
        make_silence(ffmpeg, silence)

        wav_sequence: list[Path] = []
        converted = 0
        for i, row in enumerate(selected, 1):
            src = CLIPS_DIR / row["clip"]
            dst = tmpdir / f"sample_{i:03d}.wav"
            print(f"  [{i}/{len(selected)}] {row['clip']} ({row['duration_ms']}ms) — {row['sentence'][:70]}")
            if not convert_mp3(ffmpeg, src, dst):
                print(f"    AVISO: falha ao converter, pulando")
                continue
            if wav_sequence:
                wav_sequence.append(silence)
            wav_sequence.append(dst)
            converted += 1

        if not wav_sequence:
            print("ERRO: nenhum WAV convertido com sucesso.")
            sys.exit(1)

        list_file   = tmpdir / "filelist.txt"
        kora_final  = tmpdir / "kora_final.wav"
        print(f"\nConcatenando {converted} amostras...")
        concat(ffmpeg, wav_sequence, list_file, kora_final)

        shutil.copy2(kora_final, out_wav)

    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)

    # ── transcrição ───────────────────────────────────────────────────────────
    out_txt.write_text(" ".join(r["sentence"] for r in selected), encoding="utf-8")

    # ── resumo ────────────────────────────────────────────────────────────────
    print(f"\n{'─' * 60}")
    print(f"kora.wav  → {out_wav}")
    print(f"kora.txt  → {out_txt}")
    print(f"Amostras  : {converted}")
    print(f"Duração   : {total_ms / 1000:.1f}s")
    print("Textos:")
    for row in selected:
        print(f"  • {row['sentence']}")
    print(f"{'─' * 60}")

    # ── deploy ────────────────────────────────────────────────────────────────
    if not args.no_upload:
        deploy_to_glacier(out_wav, out_txt)
    else:
        print("\n--no-upload: pulando deploy para glacier.")


if __name__ == "__main__":
    main()
