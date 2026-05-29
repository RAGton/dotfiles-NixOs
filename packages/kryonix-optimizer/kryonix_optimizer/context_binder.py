import asyncio
import json
import os
import sys
from pathlib import Path

# Armazenamento emtmpfs (RAM) - Zero escrita em disco/SSD, leitura ultrarrápida
RUN_USER_DIR = Path(f"/run/user/{os.getuid()}")
CONTEXT_FILE = RUN_USER_DIR / "kryonix_context.json"

def get_process_cwd(pid: int) -> str:
    """Inspeciona o subsistema /proc para achar o diretório real do terminal ou app focado."""
    try:
        return os.readlink(f"/proc/{pid}/cwd")
    except Exception:
        return ""

async def update_os_context(active_window_data: bytes):
    """Interpreta o estado do Hyprland e exporta a telemetria semântica atual do SO."""
    try:
        if not active_window_data:
            return
            
        data = json.loads(active_window_data.decode())
        pid = data.get("pid", 0)
        window_class = data.get("class", "")
        window_title = data.get("title", "")
        
        cwd = get_process_cwd(pid) if pid > 0 else ""
        
        # Dedução inteligente de tags de projeto baseado no ambiente de trabalho ativo
        project_tag = "general"
        if "kryonix" in cwd or "kryonix" in window_title.lower():
            project_tag = "kryonix-infra"
        elif "vault" in cwd or "obsidian" in window_class.lower():
            project_tag = "knowledge-base"
        elif "downloads" in cwd.lower():
            project_tag = "triage-inbox"

        context_payload = {
            "active_app": window_class,
            "window_title": window_title,
            "current_working_directory": cwd,
            "inferred_project_tag": project_tag,
            "timestamp": asyncio.get_event_loop().time()
        }
        
        # Escrita atômica segura para evitar race conditions em tmpfs
        temp_file = CONTEXT_FILE.with_suffix(".tmp")
        with open(temp_file, "w") as f:
            json.dump(context_payload, f, indent=2, ensure_ascii=False)
        os.rename(temp_file, CONTEXT_FILE)
        
    except Exception as e:
        print(f"[CONTEXT ERROR] Erro ao criar link de contexto: {e}", file=sys.stderr)
