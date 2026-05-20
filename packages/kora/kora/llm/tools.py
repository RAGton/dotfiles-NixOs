# =============================================================================
# Kora — Tool Definitions and Executors
#
# Three tools the agent loop can invoke via Ollama function calling:
#   graph_search       — Neo4j knowledge-graph lookup
#   get_system_time    — real system clock
#   get_system_status  — CPU/RAM + key-service health
# =============================================================================

from __future__ import annotations

import logging
from typing import Any

logger = logging.getLogger("kora.llm.tools")

# ---------------------------------------------------------------------------
# Tool schema definitions (Ollama / OpenAI function-calling format)
# ---------------------------------------------------------------------------

KORA_TOOLS: list[dict[str, Any]] = [
    {
        "type": "function",
        "function": {
            "name": "graph_search",
            "description": (
                "Consulta o grafo de conhecimento Neo4j por entidades e relações. "
                "Use para perguntas factuais sobre projetos, arquitetura, serviços "
                "ou eventos registrados em memória. "
                "NÃO use para hora atual ou status de hardware — há ferramentas específicas."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Termo ou frase de busca semântica",
                    }
                },
                "required": ["query"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_system_time",
            "description": (
                "Retorna a hora e data exatas do sistema. "
                "SEMPRE use esta ferramenta ao invés de adivinhar ou estimar o horário."
            ),
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_system_status",
            "description": (
                "Retorna uso de CPU, memória RAM e status dos serviços-chave "
                "(Ollama, Neo4j, Kora API). "
                "Use para perguntas sobre saúde, performance ou disponibilidade do sistema."
            ),
            "parameters": {"type": "object", "properties": {}},
        },
    },
]

# ---------------------------------------------------------------------------
# Dispatcher
# ---------------------------------------------------------------------------


async def execute_tool(name: str, arguments: dict[str, Any]) -> str:
    """Route a tool call to its executor and return the result as a string."""
    if name == "graph_search":
        return await _exec_graph_search(arguments.get("query", ""))
    if name == "get_system_time":
        return _exec_get_system_time()
    if name == "get_system_status":
        return await _exec_get_system_status()
    return f"[Ferramenta desconhecida: {name!r}]"


# ---------------------------------------------------------------------------
# Executors
# ---------------------------------------------------------------------------


async def _exec_graph_search(query: str) -> str:
    # Lazy import avoids circular dependency with orchestrator
    try:
        from ..core.orchestrator import _get_neo4j_driver
        from ..memory.graph import Neo4jGraphProvider

        driver = _get_neo4j_driver()
        if driver is None:
            return "Neo4j indisponível no momento."
        provider = Neo4jGraphProvider(driver)
        nodes = await provider.retrieve_context(query.strip(), top_k=5)
        result = Neo4jGraphProvider.format_for_prompt(nodes)
        return result if result else "Nenhum resultado encontrado para esta busca."
    except Exception as exc:
        logger.error("graph_search error: %s", exc)
        return f"Erro ao consultar o grafo: {exc}"


def _exec_get_system_time() -> str:
    from datetime import datetime

    _DAYS_PT = [
        "segunda-feira", "terça-feira", "quarta-feira",
        "quinta-feira", "sexta-feira", "sábado", "domingo",
    ]
    now = datetime.now()
    return (
        f"{now.strftime('%H:%M')} de {_DAYS_PT[now.weekday()]}, "
        f"{now.strftime('%d/%m/%Y')}"
    )


async def _exec_get_system_status() -> str:
    lines: list[str] = []

    # CPU / RAM via psutil (graceful fallback if not installed)
    try:
        import psutil

        cpu = psutil.cpu_percent(interval=0.3)
        mem = psutil.virtual_memory()
        lines.append(f"CPU: {cpu:.1f}%")
        lines.append(
            f"RAM: {mem.used // 1024**2}MB / {mem.total // 1024**2}MB ({mem.percent:.1f}%)"
        )
    except ImportError:
        lines.append("CPU/RAM: psutil não disponível")
    except Exception as exc:
        lines.append(f"CPU/RAM: erro — {exc}")

    # Service health checks
    import httpx

    services = {
        "Ollama": "http://127.0.0.1:11434/api/version",
        "Kora API": "http://127.0.0.1:8787/health",
    }
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(3.0)) as client:
            for svc, url in services.items():
                try:
                    r = await client.get(url)
                    lines.append(f"{svc}: {'OK' if r.is_success else f'ERRO ({r.status_code})'}")
                except Exception:
                    lines.append(f"{svc}: inativo")
    except Exception as exc:
        lines.append(f"Serviços: erro ao verificar — {exc}")

    return "\n".join(lines)
