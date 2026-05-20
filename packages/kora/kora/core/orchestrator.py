# =============================================================================
# Kora — Core Orchestrator (Intelligence Core)
#
# O orquestrador central da Kora. Recebe uma mensagem, decide a intenção
# via router, monta o plano, puxa contexto, chama o LLM, e avalia a resposta
# via quality guard.
# =============================================================================

from __future__ import annotations

import warnings
warnings.filterwarnings("ignore", module="neo4j")

import asyncio
import json
import logging
import os
import re
import socket
import subprocess
import time
from pathlib import Path
from typing import Any, AsyncGenerator, Dict, List, Optional

from ..audit.events import log_event
from ..core.config import load_system_prompt, NEO4J_URI, NEO4J_USER, NEO4J_PASSWORD, OLLAMA_MODEL
from ..core.policy import AUTHORIZED_ADMINS, PolicyContext, RiskLevel, classify_command
from ..integrations import brain as brain_adapter
from ..integrations.n8n import N8nClient
from ..llm import ollama as ollama_adapter
from ..memory import MemoryCandidate, MemoryClassifier, MemoryQueue, MemoryType
from ..memory.graph import Neo4jGraphProvider
from .grounding import requires_rag, validate_command_hallucination
from .tool_registry import get_registry_summary, find_tool
from .conversation import get_recent_turns
from .identity import (
    detect_runtime_identity,
    resolve_identity,
    should_greet,
    get_identity_response,
    is_identity_query
)

from .router import CognitiveRouter, Intent
from .capabilities import get_deterministic_capabilities_response
from .answer_planner import AnswerPlanner
from .quality import QualityGuard
from .normalizer import normalize_text
from ..mind import KoraMind, MindInput, MindConstructor, MindResult
from ..training import record_interaction

logger = logging.getLogger("kora.core.orchestrator")

import collections
import hashlib

class SimpleLRUCache:
    def __init__(self, capacity: int = 256):
        self.capacity = capacity
        self.cache = collections.OrderedDict()

    def get(self, key: str) -> Any | None:
        if key not in self.cache:
            return None
        self.cache.move_to_end(key)
        return self.cache[key]

    def put(self, key: str, value: Any):
        if key in self.cache:
            self.cache.move_to_end(key)
        self.cache[key] = value
        if len(self.cache) > self.capacity:
            self.cache.popitem(last=False)

    def clear(self):
        self.cache.clear()

_CAG_CACHE = SimpleLRUCache(capacity=256)
_LAST_GRAPH_MTIME = 0.0

def _check_and_invalidate_cache():
    global _LAST_GRAPH_MTIME
    graph_path = Path("/var/lib/kryonix/brain/storage/graph_chunk_entity_relation.graphml")
    if graph_path.exists():
        try:
            mtime = graph_path.stat().st_mtime
            if _LAST_GRAPH_MTIME == 0.0:
                _LAST_GRAPH_MTIME = mtime
            elif mtime > _LAST_GRAPH_MTIME:
                logger.info("GraphRAG index rebuild detected. Clearing CAG cache.")
                _CAG_CACHE.clear()
                _LAST_GRAPH_MTIME = mtime
        except Exception as e:
            logger.warning(f"Error checking graph file modification time: {e}")

ACTION_PROPOSAL_RE = re.compile(r"```json\s*(\{.*?" + re.escape('"type": "action_proposal"') + r".*?\})\s*```", re.DOTALL)
SESSION_METADATA: Dict[str, Any] = {}

# Max tool-call iterations in the agentic loop (safety guard)
MAX_TOOL_ITERS = 5

# Shared async Neo4j driver — created lazily, never recreated within the process.
_neo4j_driver: Any = None
_last_neo4j_check_time: float = 0.0
_neo4j_available: bool = False


def _get_neo4j_driver() -> Any | None:
    """Return the module-level async Neo4j driver, creating it on first call."""
    global _neo4j_driver, _last_neo4j_check_time, _neo4j_available
    if _neo4j_driver is not None:
        return _neo4j_driver

    now = time.monotonic()
    if now - _last_neo4j_check_time > 60.0:
        _last_neo4j_check_time = now
        from urllib.parse import urlparse
        # Priority: KRYONIX_NEO4J_URI env override → config NEO4J_URI → localhost
        uri = os.getenv("KRYONIX_NEO4J_URI") or NEO4J_URI
        if "://" not in uri:
            uri = "bolt://" + uri
        try:
            parsed = urlparse(uri)
            host = parsed.hostname or "localhost"
            port = parsed.port or 7687
            with socket.create_connection((host, port), timeout=1.0):
                _neo4j_available = True
        except Exception:
            _neo4j_available = False
            logger.debug("Neo4j connection failed (host=%s), proceeding without memory.", uri)

    if not _neo4j_available:
        return None

    try:
        from neo4j import AsyncGraphDatabase, basic_auth
        # Read NEO4J_AUTH at call time so systemd EnvironmentFile injection is
        # visible even if config.py was imported before the env was populated.
        auth_str = os.getenv("NEO4J_AUTH", "")
        if auth_str and "/" in auth_str:
            _u, _p = auth_str.split("/", 1)
            auth = basic_auth(_u, _p)
        elif NEO4J_USER and NEO4J_PASSWORD:
            auth = basic_auth(NEO4J_USER, NEO4J_PASSWORD)
        else:
            auth = None
        uri = os.getenv("KRYONIX_NEO4J_URI") or NEO4J_URI
        if "://" not in uri:
            uri = "bolt://" + uri
        _neo4j_driver = AsyncGraphDatabase.driver(uri, auth=auth)
        logger.info("Neo4j async driver initialised (uri=%s auth=%s)", uri, bool(auth))
    except Exception as exc:
        # Debug log: show URI and user (never password) for SRE diagnostics
        _debug_user = os.getenv("KRYONIX_NEO4J_USER", NEO4J_USER) or "(none)"
        _debug_uri = os.getenv("KRYONIX_NEO4J_URI") or NEO4J_URI
        logger.debug("Neo4j driver unavailable — uri=%s user=%s error: %s", _debug_uri, _debug_user, exc)
        _neo4j_driver = None
    return _neo4j_driver


async def _query_graph_context(
    query: str, top_k: int = 3
) -> tuple[str, str, str | None]:
    """
    Query the Neo4j knowledge graph for nodes related to *query*.

    Returns
    -------
    (prompt_block, raw_json, graph_node_id)
        *prompt_block*   — markdown block ready for system prompt injection.
        *raw_json*       — bare JSON string for MindConstructor reasoning.
        *graph_node_id*  — first node id for audit (None if no results).
    All three are empty/None when the driver is unavailable or no nodes found.
    """
    driver = _get_neo4j_driver()
    if driver is None:
        return "", "", None

    provider = Neo4jGraphProvider(driver)
    nodes = await provider.retrieve_context(query, top_k=top_k)

    if not nodes:
        logger.debug("GraphRAG: no nodes found for query=%r", query)
        return "", "", None

    graph_node_id: str | None = nodes[0].get("id")
    raw_json = Neo4jGraphProvider.format_for_prompt(nodes)
    prompt_block = (
        "\n\n## Memória de Longo Prazo (GraphRAG — Neo4j)\n"
        "Os seguintes nós do grafo de conhecimento são relevantes para esta query:\n"
        f"```json\n{raw_json}\n```"
    )
    return prompt_block, raw_json, graph_node_id

async def _prepare_session_and_context(
    message: str,
    session_id: str,
    user: str,
    speaker: Optional[str],
    is_voice: bool,
    mode: str,
    intent: str = "general_chat"
) -> Dict[str, Any]:
    t0 = time.monotonic()
    is_new_session = session_id not in SESSION_METADATA

    if is_new_session:
        SESSION_METADATA[session_id] = {"user": user, "speaker": speaker, "timestamp": t0}
    else:
        old_meta = SESSION_METADATA[session_id]
        if old_meta.get("user") != user or old_meta.get("speaker") != speaker:
            SESSION_METADATA[session_id] = {"user": user, "speaker": speaker, "timestamp": t0}

    runtime_info = detect_runtime_identity()
    if user and user != "unknown":
        runtime_info["user"] = user

    identity_ctx = resolve_identity(runtime_info)
    profile = identity_ctx["resolved_identity"]
    identity_trust = identity_ctx["identity_trust"]

    greeting = ""
    if should_greet(profile):
        greeting = get_identity_response(profile)

    system_prompt = load_system_prompt()

    profile_context = ""
    if profile:
        profile_context = (
            f"\n\n## Perfil do Usuário Reconhecido\n"
            f"- Nome: {profile['full_name']} ({profile['display_name']})\n"
            f"- Papel: {profile['role']}\n"
            f"- Preferências Estáticas: {', '.join(profile['preferences'])}\n"
        )
        system_prompt += profile_context

    # Injeção de aprendizados dinâmicos (Personal Learning Engine)
    try:
        from kora.core.learning import LearningEngine
        learning_engine = LearningEngine()
        learned_profile = learning_engine.get_profile(user)

        learned_context = f"\n\n## Perfil de Aprendizado Dinâmico (Kora Learning Engine)\n"
        if learned_profile.get("active_projects"):
            learned_context += f"- Projetos Ativos: {', '.join(learned_profile['active_projects'])}\n"
        if learned_profile.get("technical_vocabulary"):
            learned_context += f"- Vocabulário de Interesse: {', '.join(learned_profile['technical_vocabulary'])}\n"
        if learned_profile.get("user_preferences"):
            learned_context += f"- Preferências Aprendidas: {', '.join(learned_profile['user_preferences'])}\n"
        system_prompt += learned_context
        profile_context += learned_context
    except Exception as e:
        logger.error(f"Erro ao injetar perfil de aprendizado dinâmico: {e}")

    # Injeção de Diretrizes de Estilo de Voz (Voice Style Profile)
    if user in ["rocha", "ragton"]:
        style_directive = (
            "\n\n## 🎙️ Diretrizes de Voz e Tom (Gabriel/Ragton)\n"
            "- **Tom de Voz**: Responda com naturalidade tecnica, calma e profissional. Sem firula e sem despejar status interno em conversa casual.\n"
            "- **Estilo Cognitivo**: Seja uma parceira de engenharia técnica. Use termos técnicos avançados do NixOS/Glacier e Linux com precisão.\n"
            "- **Estrutura de Fala**: Suas respostas devem ser concisas e estruturadas em parágrafos ou tópicos curtos (ideal para leitura TTS fluida, sem blocos de texto massivos).\n"
            "- **Anti-Programa**: Responda primeiro ao humano, depois ao sistema.\n"
        )
    elif user in ["nina", "nicoly"]:
        style_directive = (
            "\n\n## 🎙️ Diretrizes de Voz e Tom (Nicoly)\n"
            "- **Tom de Voz**: Responda com um tom feminino, amigável, educado e prestativo.\n"
            "- **Estilo Cognitivo**: Ajude com tarefas gerais, mantendo segredo sobre memórias ou privilégios de administrador do Ragton.\n"
            "- **Estrutura de Fala**: Simples, direta e agradável.\n"
        )
    else:
        style_directive = (
            "\n\n## 🎙️ Diretrizes de Voz e Tom (Visitante)\n"
            "- **Tom de Voz**: Responda com um tom feminino, neutro, impessoal e estritamente informativo.\n"
            "- **Restrição**: Não revele detalhes operacionais ou preferências privadas.\n"
        )
    system_prompt += style_directive

    # Injeção de Consciência Operacional (Live System State)
    try:
        from kora.core.operational import get_operational_context, format_operational_prompt
        oper_ctx = get_operational_context()
        oper_prompt = format_operational_prompt(oper_ctx)
        system_prompt += f"\n\n{oper_prompt}"
    except Exception as e:
        logger.error(f"Erro ao injetar consciência operacional: {e}")

    identity_context = (
        f"\n\n## Identidade do Usuário Atual\n"
        f"- Usuário do sistema (Claimed): {user}\n"
        f"- Nível de Confiança: {identity_trust}\n"
        f"- Orígem: {'Voz' if is_voice else 'Terminal/Chat'}\n"
        f"- Reconhecido como: {profile['display_name'] if profile else 'Desconhecido'}\n"
        f"- Sessão: {session_id}\n"
    )
    if user in AUTHORIZED_ADMINS:
        identity_context += "- Autorização: Administrador Kryonix (Local)\n"
    else:
        identity_context += "- Autorização: Usuário não privilegiado (Restrito)\n"

    if greeting:
        identity_context += f"- Saudação sugerida: {greeting}\n"

    system_prompt += identity_context

    if identity_trust == "hint":
        system_prompt += (
            "\n\n## CONSTRANGIMENTOS DE SEGURANÇA (TRUST: HINT)\n"
            "O usuário atual foi identificado apenas por hint de ambiente/USER (não verificado).\n"
            "1. Você PODE usar o nome e preferências do usuário para personalizar a conversa e saudação.\n"
            "2. Você **NÃO DEVE** revelar segredos, senhas, chaves privadas ou dados de alta confidencialidade.\n"
            "3. Você **NÃO DEVE** propor comandos de alto risco silenciosamente.\n"
        )

    registry_summary = get_registry_summary()
    system_prompt += f"\n\n## Ferramentas Disponíveis (Tool Registry)\n{registry_summary}"

    return {
        "system_prompt": system_prompt,
        "context_text": "",
        "active_mode": "agent",
        "brain_used": False,
        "searched_files": [],
        "start_time": t0,
        "trust_level": identity_trust,
        "wake_word_ready": False,
        "speaker_id_ready": False,
        "greeting": greeting,
        "profile_context": profile_context,
        "identity_trust": identity_trust,
        "system_state": {
            "active_mode": "agent",
            "brain_used": False,
            "wake_word_ready": False,
            "speaker_id_ready": False,
        },
        "safety_context": {
            "voice_never_authorizes_critical_actions": True,
            "wake_word_ready": False,
            "speaker_id_ready": False,
            "identity_trust": identity_trust,
        },
    }

async def _agent_loop(
    query: str,
    system_prompt: str,
    history: list[dict[str, str]],
) -> str:
    """
    Agentic ReAct loop: send the query to Ollama with KORA_TOOLS, execute any
    requested tool calls, feed results back, and repeat until the model
    returns a final text answer (no tool_calls) or MAX_TOOL_ITERS is reached.
    """
    from ..llm.tools import KORA_TOOLS, execute_tool
    from ..llm.ollama import chat_with_tools as _chat_with_tools

    messages: list[dict] = [
        {"role": "system", "content": system_prompt},
        *history,
        {"role": "user", "content": query},
    ]

    last_msg: dict = {}
    for iteration in range(MAX_TOOL_ITERS):
        last_msg = await _chat_with_tools(messages, KORA_TOOLS)
        tool_calls: list[dict] | None = last_msg.get("tool_calls")

        if not tool_calls:
            return last_msg.get("content") or "Não obtive uma resposta."

        # Append the assistant turn (must include tool_calls for Ollama history)
        messages.append(last_msg)

        for call in tool_calls:
            fn = call.get("function", {})
            tool_name = fn.get("name", "")
            tool_args = fn.get("arguments") or {}
            logger.info("Agent tool call: %s(%s)", tool_name, tool_args)
            result = await execute_tool(tool_name, tool_args)
            logger.info("Agent tool result [%s]: %.120s", tool_name, result)
            messages.append({"role": "tool", "content": result, "name": tool_name})

    return last_msg.get("content") or "Atingi o limite de operações encadeadas. Tente novamente."


async def _handle_action_proposal(answer: str, user: str, session_id: str) -> tuple[str, Optional[dict]]:
    match = ACTION_PROPOSAL_RE.search(answer)
    if not match:
        return answer, None

    json_text = match.group(1)
    cleaned_answer = answer[:match.start()].strip() + "\n" + answer[match.end():].strip()

    try:
        proposal = json.loads(json_text)
        action_type = proposal.get("action")

        if action_type == "command_execute":
            command = proposal.get("command")
            if not command:
                return cleaned_answer, {"error": "Comando não especificado na proposta."}

            hallucination_error = validate_command_hallucination(command)
            if hallucination_error:
                return cleaned_answer + f"\n\n⚠️ {hallucination_error}", None

            id_ctx = resolve_identity({"user": user})
            ctx = PolicyContext(user=user, trust=id_ctx["identity_trust"], source=id_ctx["permission_source"])
            risk = classify_command(command, context=ctx)
            proposal["risk"] = risk.value

            if risk in [RiskLevel.MEDIUM, RiskLevel.HIGH, RiskLevel.CRITICAL] or proposal.get("requires_confirmation"):
                await _save_pending_action(command, risk, user)
                proposal["requires_confirmation"] = True

            return cleaned_answer, proposal

        elif action_type == "n8n_workflow":
            proposal["requires_confirmation"] = True
            await _save_pending_action(f"n8n:{proposal.get('path')}", RiskLevel.MEDIUM, user)
            return cleaned_answer, proposal

    except Exception as e:
        logger.error("Failed to parse action proposal: %s", e)
        return answer, {"error": f"Erro ao processar proposta: {e}"}

    return cleaned_answer, None

async def _save_pending_action(command: str, risk: RiskLevel, user: str):
    state_dir = Path.home() / ".local/state/kryonix/kora"
    state_dir.mkdir(parents=True, exist_ok=True)
    state_file = state_dir / "pending_action.json"
    data = {"command": command, "risk": risk.value, "user": user, "timestamp": time.time()}
    with open(state_file, "w") as f:
        json.dump(data, f)
    logger.info("Pending action saved: %s (Risk: %s)", command, risk.value)

async def process_message(
    message: str,
    session_id: str = "default",
    user: str = "unknown",
    speaker: str | None = None,
    is_voice: bool = False,
    mode: str = "auto",
) -> dict[str, Any]:
    """
    Main entry point. Routes every message through the agentic loop:
      LLM + KORA_TOOLS (graph_search, get_system_time, get_system_status)
    The LLM decides which tools to call; no intent-based if/else routing.
    """
    t0 = time.monotonic()
    original_message = message

    normalized = normalize_text(message, user)
    message = normalized.normalized

    # Build rich system prompt (user profile, style, operational context)
    ctx = await _prepare_session_and_context(
        message, session_id, normalized.user_id, speaker, is_voice, mode
    )

    system_prompt = ctx["system_prompt"]
    if normalized.corrections_applied:
        system_prompt += (
            "\n\n## Normalização aplicada\n"
            f"- original: {original_message}\n"
            f"- normalizado: {message}\n"
            f"- correções: {normalized.corrections_applied}\n"
        )
    if normalized.aliases_detected:
        system_prompt += (
            f"\n\n## Aliases detectados\n"
            f"{json.dumps(normalized.aliases_detected, ensure_ascii=False)}\n"
        )

    # Convert stored turns to message format for agent loop
    recent_turns = get_recent_turns(limit=6)
    history: list[dict[str, str]] = []
    for turn in recent_turns:
        u = str(turn.get("user") or "").strip()
        k = str(turn.get("kora") or "").strip()
        if u:
            history.append({"role": "user", "content": u})
        if k:
            history.append({"role": "assistant", "content": k})

    # Agentic loop
    answer = await _agent_loop(query=message, system_prompt=system_prompt, history=history)

    asyncio.create_task(_process_background_memory(message, answer, normalized.user_id))

    from .conversation import append_turn
    append_turn(user_text=message, assistant_text=answer, intent="agent")

    _record_training_event(
        user=normalized.user_id,
        source="voice" if is_voice else "text",
        original_message=original_message,
        normalized_message=message,
        intent="agent",
        answer=answer,
        brain_used=False,
        used_tool=True,
    )

    return {
        "answer": answer.strip(),
        "action": None,
        "mode": "agent",
        "brain_used": False,
        "elapsed_sec": round(time.monotonic() - t0, 2),
        "model": OLLAMA_MODEL,
    }


def _record_training_event(
    *,
    user: str,
    source: str,
    original_message: str,
    normalized_message: str,
    intent: str,
    answer: str,
    brain_used: bool,
    used_tool: bool,
) -> None:
    try:
        record_interaction(
            user_id=user,
            source=source,
            original_text=original_message,
            normalized_text=normalized_message,
            intent=intent,
            answer=answer,
            used_rag=brain_used,
            used_tool=used_tool,
        )
    except Exception as exc:
        logger.error("Training event logging failed: %s", exc)

async def process_message_stream(
    message: str,
    session_id: str = "default",
    user: str = "unknown",
    speaker: str | None = None,
    is_voice: bool = False,
    mode: str = "auto",
) -> AsyncGenerator[str, None]:
    result = await process_message(
        message=message,
        session_id=session_id,
        user=user,
        speaker=speaker,
        is_voice=is_voice,
        mode=mode,
    )
    yield f"data: {json.dumps({'type': 'meta', 'mode': result.get('mode'), 'session_id': session_id})}\n\n"
    answer = result.get("answer", "")
    for chunk in [answer[i:i + 40] for i in range(0, len(answer), 40)]:
        yield f"data: {json.dumps({'type': 'content', 'chunk': chunk})}\n\n"
        await asyncio.sleep(0.01)
    if result.get("action"):
        yield f"data: {json.dumps({'type': 'action', 'proposal': result['action']})}\n\n"
    yield f"data: {json.dumps({'type': 'stats', 'elapsed_sec': result.get('elapsed_sec', 0)})}\n\n"

async def _process_background_memory(message: str, answer: str, user: str):
    try:
        from kora.core.learning import LearningEngine
        learning_engine = LearningEngine()
        await learning_engine.learn_from_turn(message, answer, user)
    except Exception as e:
        logger.error("Background learning execution failed: %s", e)

    try:
        from kora.memory import MemoryClassifier, MemoryQueue
        from kora.llm.ollama import OllamaAdapter

        llm = OllamaAdapter()
        classifier = MemoryClassifier(llm_provider=llm)
        candidates = await classifier.classify(message, answer, user=user)
        if candidates:
            queue = MemoryQueue()
            for c in candidates:
                queue.push(c)
    except Exception as e:
        logger.error("Background memory processing failed: %s", e)

async def _background_self_heal(
    session_id: str,
    query: str,
    result: "MindResult",
) -> None:
    """
    Background task: audit thought history for the failing query and stage
    a knowledge-graph triple for human review via KnowledgeResearcher.

    Never writes to Neo4j directly — all proposed changes go through
    the HitL staging pipeline (status=pending_review).
    Exceptions are logged and swallowed so callers are never affected.
    """
    try:
        from ..mind.auditor import ThoughtAuditor
        from ..agents.researcher import KnowledgeResearcher

        auditor = ThoughtAuditor()
        failures = auditor.get_frequent_failures(confidence_threshold=0.65)

        target = next(
            (f for f in failures if f.query.startswith(query[:50])),
            None,
        )
        if target is None:
            logger.debug("Self-heal: no frequent failure recorded for query=%s", query[:60])
            return

        researcher = KnowledgeResearcher()
        staged = await researcher.research_and_stage(target)
        if staged:
            log_event(
                event_type="self_heal_staged",
                description="KnowledgeResearcher staged a triple for human review",
                metadata={
                    "session_id":  session_id,
                    "query":       query[:200],
                    "triple_id":   staged.triple_id,
                    "subject":     staged.triple.subject_id,
                    "predicate":   staged.triple.predicate,
                    "object":      staged.triple.object_id,
                },
                risk="read_only",
            )
            logger.info(
                "Self-heal staged triple %s | session=%s confidence=%.2f",
                staged.triple_id, session_id, result.confidence,
            )
        else:
            logger.debug(
                "Self-heal: no evidence found for query=%s", query[:60]
            )
    except Exception as exc:
        logger.warning("_background_self_heal failed silently: %s", exc)


async def confirm_pending_action(session_id: str = "default") -> dict[str, Any]:
    state_file = Path.home() / ".local/state/kryonix/kora/pending_action.json"
    if not state_file.exists():
        return {"status": "error", "message": "Nenhuma ação pendente."}

    try:
        with open(state_file, "r") as f:
            data = json.load(f)
        command = data.get("command")

        if command.startswith("n8n:"):
            path = command.split(":", 1)[1]
            return {"status": "success", "message": f"Workflow n8n disparado: {path}"}

        process = subprocess.run(command, shell=True, capture_output=True, text=True, timeout=60)
        state_file.unlink()
        return {
            "status": "success" if process.returncode == 0 else "failed",
            "command": command,
            "stdout": process.stdout,
            "stderr": process.stderr,
            "returncode": process.returncode
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}
