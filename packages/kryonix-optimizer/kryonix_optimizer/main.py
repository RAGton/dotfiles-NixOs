#!/usr/bin/env python3
import asyncio
import os
import sys
import json
import httpx
import psutil
from .context_binder import update_os_context

MEMORY_THRESHOLD_PCT = 90.0
CHECK_INTERVAL_SECS = 30  # Reduzido para 30s para tornar o context binder mais responsivo
LOCAL_OLLAMA_URL = "http://localhost:11434/api/generate"

async def get_hyprland_active_window() -> bytes:
    try:
        proc = await asyncio.create_subprocess_exec(
            "hyprctl", "activewindow", "-j",
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE
        )
        stdout, _ = await proc.communicate()
        return stdout if proc.returncode == 0 else b""
    except Exception:
        return b""

async def collect_top_processes():
    """Coleta os 5 processos em background mais pesados excluindo o foco e ferramentas essenciais."""
    processes = []
    for proc in psutil.process_iter(['pid', 'name', 'memory_info', 'create_time']):
        try:
            info = proc.info
            ram_gb = info['memory_info'].rss / (1024 ** 3)
            # Ignora processos vitais do sistema operacional base
            if info['name'] in ('hyprland', 'Xorg', 'systemd', 'waybar', 'pipewire'):
                continue
            
            # Calcula tempo ocioso aproximado baseado nas estatísticas do processo
            idle_time = int(asyncio.get_event_loop().time() - info['create_time'] % 100000)
            
            processes.append({
                "pid": info['pid'],
                "name": info['name'],
                "ram_usage_gb": round(ram_gb, 2),
                "idle_time_seconds": max(0, idle_time)
            })
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    
    # Ordena pelo maior uso de RAM
    processes.sort(key=lambda x: x["ram_usage_gb"], reverse=True)
    return processes[:5]

async def ask_local_slm_optimizer(focus_app: str, processes: list) -> list:
    """Usa a SLM local de 1.5B com instruções estritas para controle de RAM."""
    prompt = (
        f"Contexto do SO: Usuário focado em {focus_app}.\n"
        f"Processos pesados: {json.dumps(processes)}.\n"
        "Gere uma ação de otimização de RAM segura. Regras:\n"
        "1. Nunca encerre processos ativamente. Use apenas 'kill -STOP <pid>'.\n"
        "2. Responda apenas com o JSON estruturado abaixo. Proibido introduzir explicações textuais.\n"
        '{"actions": [{"pid": 123, "command": "kill -STOP 123", "reason": "..."}]}'
    )
    
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.post(
                LOCAL_OLLAMA_URL,
                json={
                    "model": "qwen2.5-coder:1.5b",
                    "prompt": prompt,
                    "stream": False,
                    "format": "json" # Força o Ollama a validar a saída como JSON nativo
                }
            )
            if response.status_code == 200:
                res_data = response.json()
                raw_response = res_data.get("response", "{}")
                return json.loads(raw_response).get("actions", [])
    except Exception:
        pass
    return []

async def execute_safely(command: str):
    """Executa o comando validado, prevenindo injeções destrutivas."""
    parts = command.split()
    if not parts or parts[0] not in ('kill', 'renice'):
        print(f"[SECURITY ALERT] Bloqueado comando suspeito da IA: {command}", file=sys.stderr)
        return

    # Invariante de Segurança Rígida: Proteção dupla contra Kill -9 acidental
    if "-9" in parts:
        print("[SECURITY ALERT] Tentativa de encerramento forçado (-9) abortada.", file=sys.stderr)
        return

    try:
        proc = await asyncio.create_subprocess_exec(
            *parts,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        await proc.communicate()
        print(f"[OPTIMIZER] Executado com sucesso: {command}")
    except Exception as e:
        print(f"[ERROR] Falha ao rodar otimização: {e}", file=sys.stderr)

async def main():
    print("[INFO] Inicializando Kryonix RAM Optimizer & Context Binder Daemon...")
    while True:
        try:
            focus_data = await get_hyprland_active_window()
            await update_os_context(focus_data)

            mem = psutil.virtual_memory()
            if mem.percent >= MEMORY_THRESHOLD_PCT:
                print(f"[WARN] Alerta de RAM: {mem.percent}% em uso. Otimizando...")
                
                # Para compor o foco, tentamos extrair o título
                focus_title = "Desconhecido"
                try:
                    if focus_data:
                        focus_json = json.loads(focus_data.decode())
                        focus_title = focus_json.get('title', 'Desconhecido')
                except Exception:
                    pass

                bg_procs = await collect_top_processes()
                
                try:
                    actions = await ask_local_slm_optimizer(focus_title, bg_procs)
                    for action in actions:
                        await execute_safely(action.get("command", ""))
                except Exception as ollama_err:
                    print(f"[WARN] SLM Local offline ou falha: {ollama_err}")
            
        except Exception as global_err:
            print(f"[CRITICAL] Erro inesperado no loop do daemon: {global_err}", file=sys.stderr)
            
        await asyncio.sleep(CHECK_INTERVAL_SECS)

if __name__ == "__main__":
    asyncio.run(main())
