import os
import shutil
import subprocess
import socket
import logging
from datetime import datetime
from typing import Dict, Any

logger = logging.getLogger("kora.core.operational")

def get_cpu_load() -> str:
    """Gera string descritiva do load da CPU."""
    try:
        if hasattr(os, "getloadavg"):
            load = os.getloadavg()
            return f"{load[0]:.2f}, {load[1]:.2f}, {load[2]:.2f}"
    except Exception:
        pass
    return "N/A"

def get_ram_usage() -> str:
    """Gera string descritiva do uso de memória RAM lendo /proc/meminfo."""
    try:
        with open("/proc/meminfo", "r") as f:
            lines = f.readlines()
        mem_total = 0
        mem_free = 0
        mem_available = 0
        for line in lines:
            if line.startswith("MemTotal:"):
                mem_total = int(line.split()[1])
            elif line.startswith("MemFree:"):
                mem_free = int(line.split()[1])
            elif line.startswith("MemAvailable:"):
                mem_available = int(line.split()[1])
        
        if mem_total > 0:
            # MemAvailable é o indicador mais preciso de RAM disponível no Linux moderno
            free_kb = mem_available if mem_available > 0 else mem_free
            used_kb = mem_total - free_kb
            used_gb = used_kb / (1024 * 1024)
            total_gb = mem_total / (1024 * 1024)
            percent = (used_kb / mem_total) * 100
            return f"{used_gb:.1f}GB / {total_gb:.1f}GB ({percent:.1f}%)"
    except Exception:
        pass
    return "N/A"

def get_disk_usage(path: str = "/") -> str:
    """Gera string descritiva do uso do disco no path indicado."""
    try:
        total, used, free = shutil.disk_usage(path)
        total_gb = total / (1024**3)
        used_gb = used / (1024**3)
        percent = (used / total) * 100
        return f"{used_gb:.1f}GB / {total_gb:.1f}GB ({percent:.1f}%)"
    except Exception:
        pass
    return "N/A"

def get_git_status(repo_path: str = "/etc/kryonix") -> Dict[str, Any]:
    """Coleta o status do repositório Git de forma segura."""
    result = {
        "branch": "desconhecido",
        "commit": "desconhecido",
        "status": "CLEAN"
    }
    
    if not os.path.exists(os.path.join(repo_path, ".git")):
        return result

    try:
        # Pega a branch ativa
        branch_proc = subprocess.run(
            ["git", "-C", repo_path, "rev-parse", "--abbrev-ref", "HEAD"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=2
        )
        if branch_proc.returncode == 0:
            result["branch"] = branch_proc.stdout.strip()

        # Pega o commit curto
        commit_proc = subprocess.run(
            ["git", "-C", repo_path, "rev-parse", "--short", "HEAD"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=2
        )
        if commit_proc.returncode == 0:
            result["commit"] = commit_proc.stdout.strip()

        # Verifica se está dirty
        status_proc = subprocess.run(
            ["git", "-C", repo_path, "status", "--short"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=2
        )
        if status_proc.returncode == 0 and status_proc.stdout.strip():
            result["status"] = "DIRTY"
            
    except Exception as e:
        logger.debug(f"Falha ao ler status do Git em {repo_path}: {e}")

    return result

def is_glacier_online(ip: str = "10.0.0.2", port: int = 8000) -> bool:
    """Testa conexão rápida de rede para verificar se o Glacier está online."""
    try:
        with socket.create_connection((ip, port), timeout=1.0) as s:
            return True
    except (socket.timeout, ConnectionRefusedError, OSError):
        pass
    return False

def get_operational_context(repo_path: str = "/etc/kryonix") -> Dict[str, Any]:
    """Consolida toda a consciência operacional em um único dicionário pronto para injeção."""
    now = datetime.now()
    
    # Formatação de data/hora em português
    dias_semana = ["Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado", "Domingo"]
    dia_pt = dias_semana[now.weekday()]
    timestamp_pt = f"{dia_pt}, {now.strftime('%d de %B de %Y às %H:%M')}"
    
    git_ctx = get_git_status(repo_path)
    
    # Detecção se está rodando no Inspiron ou Glacier
    hostname = socket.gethostname()
    
    # Glacier status check
    glacier_online = is_glacier_online() if hostname == "inspiron" else True

    return {
        "timestamp": timestamp_pt,
        "hostname": hostname,
        "cpu_load": get_cpu_load(),
        "ram_usage": get_ram_usage(),
        "disk_usage": get_disk_usage(),
        "disk_kora_usage": get_disk_usage("/var/lib/kryonix"),
        "git_branch": git_ctx["branch"],
        "git_commit": git_ctx["commit"],
        "git_status": git_ctx["status"],
        "glacier_online": glacier_online
    }

def format_operational_prompt(ctx: Dict[str, Any]) -> str:
    """Gera bloco de prompt formatado para injeção no System Prompt."""
    glacier_status = "Online e conectado" if ctx["glacier_online"] else "OFFLINE ou Inalcançável (conexões remotas limitadas)"
    
    return f"""## 🖥️ Consciência Operacional (Live System State)
- **Host**: {ctx['hostname']} (NixOS Workstation)
- **Local Time**: {ctx['timestamp']}
- **CPU Load**: {ctx['cpu_load']}
- **RAM lida**: {ctx['ram_usage']}
- **Uso de Disco (/)**: {ctx['disk_usage']}
- **Uso de Disco (/var/lib/kryonix)**: {ctx['disk_kora_usage']}
- **Repositório `/etc/kryonix`**: Ramo `{ctx['git_branch']}` (commit `{ctx['git_commit']}` - STATUS: {ctx['git_status']})
- **Glacier (Server IA)**: {glacier_status}
"""
