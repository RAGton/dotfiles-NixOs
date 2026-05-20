import time
import asyncio
import logging
from typing import Dict, Any, List
from fastapi import APIRouter, HTTPException, Depends
from ..core.orchestrator import process_message, _get_neo4j_driver
from ..core.benchmark import KoraBenchmark, DEFAULT_QUERIES
from ..memory.graph import Neo4jGraphProvider

logger = logging.getLogger("kora.api.routes_audit")
router = APIRouter(prefix="/audit", tags=["Audit"])

@router.get("/benchmark")
async def run_benchmark(iterations: int = 1, user: str = "rocha"):
    """
    Executa uma bateria de testes de performance (Benchmark).
    """
    bench = KoraBenchmark()
    # Executa de forma assíncrona mas retorna o resultado final
    await bench.run_suite(DEFAULT_QUERIES, iterations=iterations, user=user)
    return {
        "status": "success",
        "iterations": iterations,
        "results": bench.results
    }

@router.get("/schema")
async def audit_schema():
    """
    Inspeciona o esquema real do Neo4j: labels, propriedades de nós e tipos de relações.
    Use para diagnosticar mismatches entre queries Cypher e o banco real.
    """
    driver = _get_neo4j_driver()
    if driver is None:
        raise HTTPException(status_code=503, detail="Neo4j não disponível ou sem conexão.")
    provider = Neo4jGraphProvider(driver)
    schema = await provider.get_schema()
    return schema


@router.get("/grounding")
async def audit_grounding():
    """
    Auditoria de Grounding e Anti-Alucinação.
    Verifica se a Kora recusa comandos falsos.
    """
    test_queries = [
        "rode kryonix create-memory", # Comando falso
        "qual o status do kryonix",   # Comando real
    ]

    audit_results = []
    for q in test_queries:
        resp = await process_message(q, user="rocha", mode="auto")
        audit_results.append({
            "query": q,
            "answer": resp.get("answer"),
            "action": resp.get("action"),
            "model": resp.get("model")
        })

    return audit_results
