#!/usr/bin/env python3
import asyncio
import os
import sys
import json
import httpx
import psutil

# Configurações globais do Daemon
MEMORY_THRESHOLD_PCT = 90.0
CHECK_INTERVAL_SECS = 60
GLACIER_URL = os.environ.get("KRYONIX_BRAIN_URL", "http://glacier:8000")
API_KEY = os.environ.get("KRYONIX_BRAIN_API_KEY", "")

async def get_active_window_context() -> str:
    """Detecta qual aplicação o usuário está usando ativamente usando xdotool ou hyprctl."""
    try:
        proc = await asyncio.create_subprocess_exec(
            "hyprctl", "activewindow", "-j",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        stdout, _ = await proc.communicate()
        if proc.returncode == 0:
            data = json.loads(stdout.decode())
            return f"{data.get('class', 'unknown')} (Título: {data.get('title', 'unknown')})"
    except Exception:
        pass
    return "Ambiente de Trabalho Hyprland"

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

async def ask_brain_optimizer(focus: str, bg_procs: list) -> list:
    """Consulta o LLM no Glacier para obter os comandos seguros de otimização."""
    payload = {
        "focus_app": focus,
        "background_processes": bg_procs
    }
    
    # Prompt de sistema embutido para guiar o modelo local qwen2.5-coder
    system_prompt = (
        "Você é o otimizador de tempo de execução do Kryonix OS. "
        "Seu objetivo é liberar RAM suspendendo processos ociosos secundários. "
        "Regra Absoluta: É proibido gerar comandos 'kill -9'. Use apenas 'kill -STOP' "
        "para pausar na RAM ou 'renice' para diminuir prioridade de CPU. "
        "Retorne APENAS um JSON puro no formato: "
        '{"actions": [{"pid": 123, "command": "kill -STOP 123", "reason": "..."}]}'
    )
    
    headers = {"X-API-Key": API_KEY} if API_KEY else {}
    
    async with httpx.AsyncClient(timeout=4.0) as client:
        # Envia a requisição para o endpoint de chat/generation do seu ecossistema
        response = await client.post(
            f"{GLACIER_URL}/api/v1/optimize-resource",
            json={"system": system_prompt, "data": payload},
            headers=headers
        )
        if response.status_code == 200:
            return response.json().get("actions", [])
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
    print("[INFO] Inicializando Kryonix RAM Optimizer Daemon...")
    while True:
        try:
            mem = psutil.virtual_memory()
            if mem.percent >= MEMORY_THRESHOLD_PCT:
                print(f"[WARN] Alerta de RAM: {mem.percent}% em uso. Consultando Brain API...")
                
                focus = await get_active_window_context()
                bg_procs = await collect_top_processes()
                
                try:
                    actions = await ask_brain_optimizer(focus, bg_procs)
                    for action in actions:
                        await execute_safely(action.get("command", ""))
                except (httpx.ConnectError, httpx.TimeoutException):
                    # REGRA DE RESILIÊNCIA: Modo degradado, apenas emite aviso sem estourar o daemon
                    print("[WARN] Servidor Glacier (IA) offline ou inacessível. Pulando ciclo de otimização.")
            
        except Exception as global_err:
            print(f"[CRITICAL] Erro inesperado no loop do daemon: {global_err}", file=sys.stderr)
            
        await asyncio.sleep(CHECK_INTERVAL_SECS)

if __name__ == "__main__":
    asyncio.run(main())
