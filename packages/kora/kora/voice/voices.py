# =============================================================================
# Kora Voice — Voice Presets (voices.py)
# =============================================================================
# Define presets de parâmetros Piper para diferentes estilos de voz.
# O preset ativo é salvo em /var/lib/kryonix/kora/voice/config.json.
# =============================================================================

import json
import logging
import os
import shutil
from pathlib import Path

logger = logging.getLogger("kora.voice.voices")

# ---------------------------------------------------------------------------
# Diretório de config de voz
# ---------------------------------------------------------------------------
VOICE_CONFIG_PATH = Path("/var/lib/kryonix/kora/voice/config.json")

# ---------------------------------------------------------------------------
# Catálogo de presets
# ---------------------------------------------------------------------------
VOICE_PRESETS: dict = {
    "kora_friday": {
        "provider":     "edge-tts",
        "voice":        "pt-BR-FranciscaNeural",
        "model":        "kora_ptbr_female",
        "length_scale": 1.03,
        "noise_scale":  0.35,
        "noise_w":      0.68,
        "description":  "Kora Friday — elegante, inteligente e sofisticada",
        "gender_note":  "feminina — estilo Friday/Jarvis premium (fallback local Dii/OVOS)",
    },
    "kora_ptbr_female": {
        "provider":     "edge-tts",
        "voice":        "pt-BR-FranciscaNeural",
        "model":        "kora_ptbr_female",
        "length_scale": 1.15,
        "noise_scale":  0.667,
        "noise_w":      0.8,
        "description":  "voz principal da Kora — feminina Neural Premium (Francisca)",
        "gender_note":  "feminina — voz neural ultra-realista e profissional (fallback local Dii/OVOS)",
    },
    "kora_thalita": {
        "provider":     "edge-tts",
        "voice":        "pt-BR-ThalitaNeural",
        "model":        "kora_ptbr_female",
        "length_scale": 1.15,
        "noise_scale":  0.667,
        "noise_w":      0.8,
        "description":  "voz doce da Kora — feminina Neural Doce (Thalita)",
        "gender_note":  "feminina — voz neural extremamente suave e delicada (fallback local Dii/OVOS)",
    },
    "kora_f5tts": {
        "provider":             "f5tts",
        "f5tts_endpoint":       "http://rve-glacier:7860",
        "voice_reference":      "/var/lib/f5-tts/voices/kora.wav",
        "voice_reference_text": "",
        "length_scale":         1.1,
        "description":          "F5-TTS zero-shot — voz feminina PT-BR local",
    },
    "kora_sage": {
        "provider":     "piper",
        "model":        "kora_sage",
        "length_scale": 1.32,
        "noise_scale":  0.48,
        "noise_w":      0.78,
        "description":  "voz de combate da Kora — feminina PT-BR (Sage/Valorant)",
        "gender_note":  "feminina — modelo local offline da Sage",
    },
    "edresson": {
        "provider":     "piper",
        "model":        "edresson",
        "length_scale": 1.22,
        "noise_scale":  0.667,
        "noise_w":      0.8,
        "description":  "voz feminina humanizada da Kora (edresson-low)",
        "gender_note":  "feminina — modelo local offline ultra-realista",
    },
    "default": {
        "provider":     "piper",
        "model":        "faber",
        "length_scale": 1.18,
        "noise_scale":  0.55,
        "noise_w":      0.65,
        "description":  "voz PT-BR local padrão (faber)",
        "gender_note":  "masculina/neutra — voz local padrão",
    },
    "soft": {
        "provider":     "piper",
        "model":        "faber",
        "length_scale": 1.28,
        "noise_scale":  0.45,
        "noise_w":      0.80,
        "description":  "mais lenta e suave",
        "gender_note":  "masculina/neutra — mais calma",
    },
    "fast": {
        "provider":     "piper",
        "model":        "faber",
        "length_scale": 1.00,
        "noise_scale":  0.60,
        "noise_w":      0.70,
        "description":  "mais rápida e direta",
        "gender_note":  "masculina/neutra — mais direta",
    },
    "expressive": {
        "provider":     "piper",
        "model":        "faber",
        "length_scale": 1.22,
        "noise_scale":  0.70,
        "noise_w":      0.55,
        "description":  "mais expressiva e variada",
        "gender_note":  "masculina/neutra — tom expressivo",
    },
}

DEFAULT_PRESET = os.getenv("KORA_DEFAULT_VOICE_PRESET", "kora_friday")

# ---------------------------------------------------------------------------
# Persistência
# ---------------------------------------------------------------------------

def _load_config() -> dict:
    if VOICE_CONFIG_PATH.exists():
        try:
            return json.loads(VOICE_CONFIG_PATH.read_text())
        except Exception:
            pass
    return {"active_preset": DEFAULT_PRESET}


def _save_config(cfg: dict) -> None:
    VOICE_CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    VOICE_CONFIG_PATH.write_text(json.dumps(cfg, indent=2, ensure_ascii=False))


def get_active_preset_name() -> str:
    return _load_config().get("active_preset", DEFAULT_PRESET)


def get_active_preset() -> dict:
    name = get_active_preset_name()
    return VOICE_PRESETS.get(name, VOICE_PRESETS[DEFAULT_PRESET])


def set_active_preset(name: str) -> None:
    if name not in VOICE_PRESETS:
        raise ValueError(f"Preset desconhecido: '{name}'. Disponíveis: {list(VOICE_PRESETS)}")
    cfg = _load_config()
    cfg["active_preset"] = name
    _save_config(cfg)

# ---------------------------------------------------------------------------
# CLI actions
# ---------------------------------------------------------------------------

def cmd_list() -> None:
    """Lista presets disponíveis."""
    from .models import PIPER_VOICES, PIPER_DIR

    active = get_active_preset_name()
    print("\n[PRESETS DE VOZ DISPONÍVEIS]")
    for name, preset in VOICE_PRESETS.items():
        flag = "→" if name == active else " "
        model_name = preset["model"]
        if model_name in PIPER_VOICES:
            installed = (PIPER_DIR / PIPER_VOICES[model_name]["local_model"]).exists()
        else:
            installed = (PIPER_DIR / f"pt_BR-{model_name}-medium.onnx").exists()
        status = "✓" if installed else "✗ não instalado"
        print(f"  {flag} {name:<12} [{model_name} {status}]  {preset['description']}")

    print("\n[STATUS VOZ FEMININA PT-BR]")
    female_found = False
    for name, info in PIPER_VOICES.items():
        model_file = PIPER_DIR / info["local_model"]
        if model_file.exists():
            print(f"  {name}: instalado — {info['local_model']}")
            if name == "kora_ptbr_female":
                female_found = True
    if not female_found:
        print("  female_ptbr: MISSING")
        print("  ⚠ Voz feminina PT-BR local ainda não disponível via rhasspy/piper-voices.")
        print("    → Usando preset 'soft' no modelo atual para melhor naturalidade.")
    else:
        print("  female_ptbr: ✓ OK (Kora Voice rodando com modelo Dii/OVOS premium!)")
    print()


def cmd_current() -> None:
    """Mostra preset ativo."""
    import json as _json
    name = get_active_preset_name()
    preset = get_active_preset()
    print(_json.dumps({"active_preset": name, **preset}, indent=2, ensure_ascii=False))


def cmd_set(name: str) -> None:
    """Ativa preset por nome."""
    set_active_preset(name)
    preset = VOICE_PRESETS[name]
    print(f"  ✓ Preset ativo: {name}  ({preset['description']})")
    print(f"  ℹ {preset.get('gender_note', '')}")


def cmd_test() -> None:
    """Fala frase de teste com o preset ativo."""
    from .tts import speak_text_with_preset
    preset = get_active_preset()
    name = get_active_preset_name()
    print(f"  → Testando preset '{name}' ({preset['description']})...")
    speak_text_with_preset(
        "Boa noite, Ragton. Estou online e pronta para acompanhar você.",
        preset=preset
    )
