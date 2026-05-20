# =============================================================================
# Kora — Ollama Adapter
#
# Cliente async para o runtime Ollama via httpx.
# Tolerante a falhas: nunca crash se Ollama offline.
#
# Usa HTTP direto em vez do SDK ollama-python para:
# - Menos dependências
# - Mais controle sobre timeouts e retry
# - Streaming futuro via httpx
# =============================================================================

from __future__ import annotations

import logging
from typing import Any

import httpx

from ..core.config import (
    OLLAMA_MODEL,
    OLLAMA_TIMEOUT_CHAT,
    OLLAMA_TIMEOUT_HEALTH,
    OLLAMA_URL,
)

logger = logging.getLogger("kora.llm.ollama")


async def health() -> dict[str, Any]:
    """Check Ollama availability. Returns status dict, never raises."""
    try:
        async with httpx.AsyncClient(timeout=OLLAMA_TIMEOUT_HEALTH) as client:
            resp = await client.get(f"{OLLAMA_URL}/api/tags")
            if resp.status_code == 200:
                data = resp.json()
                models = [m.get("name", "?") for m in data.get("models", [])]
                return {
                    "status": "ok",
                    "url": OLLAMA_URL,
                    "models_loaded": len(models),
                    "models": models[:10],  # cap for readability
                }
            return {
                "status": "warn",
                "url": OLLAMA_URL,
                "error": f"HTTP {resp.status_code}",
            }
    except httpx.ConnectError:
        return {"status": "fail", "url": OLLAMA_URL, "error": "connection refused"}
    except httpx.TimeoutException:
        return {"status": "fail", "url": OLLAMA_URL, "error": "timeout"}
    except Exception as e:
        return {"status": "fail", "url": OLLAMA_URL, "error": str(e)}


async def chat(
    messages: list[dict[str, str]],
    model: str | None = None,
    temperature: float = 0.7,
) -> dict[str, Any]:
    """
    Send a chat completion request to Ollama.

    Args:
        messages: List of {"role": "system"|"user"|"assistant", "content": "..."}.
        model: Ollama model name. Defaults to config OLLAMA_MODEL.
        temperature: Sampling temperature.

    Returns:
        Dict with "answer", "model", "provider" keys, or error info.
    """
    model = model or OLLAMA_MODEL
    payload = {
        "model": model,
        "messages": messages,
        "stream": False,
        "options": {
            "temperature": temperature,
        },
    }

    try:
        async with httpx.AsyncClient(
            timeout=httpx.Timeout(connect=10.0, read=None, write=60.0, pool=10.0)
        ) as client:
            resp = await client.post(f"{OLLAMA_URL}/api/chat", json=payload)
            resp.raise_for_status()
            data = resp.json()

            answer = data.get("message", {}).get("content", "")
            return {
                "answer": answer,
                "model": model,
                "provider": "ollama",
                "eval_count": data.get("eval_count"),
                "eval_duration": data.get("eval_duration"),
                "total_duration": data.get("total_duration"),
            }
    except httpx.ConnectError:
        logger.warning("Ollama offline — cannot complete chat request")
        return {
            "answer": "Ollama está offline. Não consigo processar a mensagem agora.",
            "model": model,
            "provider": "ollama",
            "error": "connection_refused",
        }
    except httpx.TimeoutException:
        logger.warning("Ollama timeout on chat request")
        return {
            "answer": "Ollama não respondeu a tempo. Tente novamente.",
            "model": model,
            "provider": "ollama",
            "error": "timeout",
        }
    except httpx.HTTPStatusError as e:
        logger.error("Ollama HTTP error: %s", e)
        return {
            "answer": f"Erro no Ollama: HTTP {e.response.status_code}",
            "model": model,
            "provider": "ollama",
            "error": f"http_{e.response.status_code}",
        }
    except Exception as e:
        logger.error("Unexpected Ollama error: %s", e)
        return {
            "answer": f"Erro inesperado ao acessar Ollama: {e}",
            "model": model,
            "provider": "ollama",
            "error": str(e),
        }
async def generate_completion(
    prompt: str,
    system_prompt: str | None = None,
    context: str | None = None,
    model: str | None = None,
    temperature: float = 0.7,
) -> dict[str, Any]:
    """
    Generate a non-streaming completion from Ollama.
    Convenience wrapper over chat().
    """
    messages = []
    if system_prompt:
        messages.append({"role": "system", "content": system_prompt})

    final_prompt = prompt
    if context:
        final_prompt = f"Contexto:\n{context}\n\nPergunta:\n{prompt}"

    messages.append({"role": "user", "content": final_prompt})

    return await chat(messages=messages, model=model, temperature=temperature)


async def generate_stream(
    prompt: str,
    system_prompt: str | None = None,
    context: str | None = None,
    model: str | None = None,
    temperature: float = 0.7,
):
    """
    Generate a streaming response from Ollama.
    Yields string chunks as they arrive.
    """
    model = model or OLLAMA_MODEL

    messages = []
    if system_prompt:
        messages.append({"role": "system", "content": system_prompt})

    final_prompt = prompt
    if context:
        final_prompt = f"Contexto:\n{context}\n\nPergunta:\n{prompt}"

    messages.append({"role": "user", "content": final_prompt})

    payload = {
        "model": model,
        "messages": messages,
        "stream": True,
        "options": {
            "temperature": temperature,
        },
    }

    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(OLLAMA_TIMEOUT_CHAT, read=None)) as client:
            async with client.stream("POST", f"{OLLAMA_URL}/api/chat", json=payload) as resp:
                resp.raise_for_status()
                async for line in resp.aiter_lines():
                    if not line:
                        continue
                    import json
                    try:
                        data = json.loads(line)
                        if "message" in data and "content" in data["message"]:
                            yield data["message"]["content"]
                    except json.JSONDecodeError:
                        continue
    except Exception as e:
        logger.error(f"Ollama stream error: {e}")
        yield f"\n[Erro na geração: {e}]"


async def chat_with_turns(
    user_message: str,
    system_prompt: str,
    conversation_turns: list[dict],
    context: str | None = None,
    model: str | None = None,
    temperature: float = 0.45,
) -> dict[str, Any]:
    """
    Multi-turn chat with proper message format.

    Passes conversation history as real user/assistant messages — not injected
    as text into the system prompt. Models understand this format natively,
    which produces better context recall and natural follow-up answers.
    """
    messages: list[dict[str, str]] = [{"role": "system", "content": system_prompt}]

    for turn in conversation_turns[-6:]:  # last 3 exchanges (6 half-turns)
        user_text = str(turn.get("user") or "").strip()
        kora_text = str(turn.get("kora") or "").strip()
        if user_text:
            messages.append({"role": "user", "content": user_text})
        if kora_text:
            messages.append({"role": "assistant", "content": kora_text})

    final_message = user_message
    if context:
        final_message = f"Contexto:\n{context}\n\n---\n{user_message}"

    messages.append({"role": "user", "content": final_message})
    return await chat(messages=messages, model=model, temperature=temperature)


async def chat_with_tools(
    messages: list[dict],
    tools: list[dict],
    model: str | None = None,
    temperature: float = 0.45,
) -> dict[str, Any]:
    """
    POST /api/chat with Ollama tool-calling support.

    Returns the raw message dict:
      - {"role": "assistant", "content": "...", "tool_calls": None}  — final answer
      - {"role": "assistant", "content": "", "tool_calls": [...]}     — tool call(s)

    tool_calls items have shape: {"function": {"name": "...", "arguments": {...}}}
    """
    model = model or OLLAMA_MODEL
    payload = {
        "model": model,
        "messages": messages,
        "tools": tools,
        "stream": False,
        "options": {"temperature": temperature},
    }
    try:
        async with httpx.AsyncClient(
            timeout=httpx.Timeout(connect=10.0, read=None, write=60.0, pool=10.0)
        ) as client:
            resp = await client.post(f"{OLLAMA_URL}/api/chat", json=payload)
            resp.raise_for_status()
            return resp.json()["message"]
    except httpx.ConnectError:
        logger.warning("Ollama offline — cannot complete tool chat")
        return {"role": "assistant", "content": "Ollama está offline.", "tool_calls": None}
    except httpx.TimeoutException:
        logger.warning("Ollama timeout on tool chat")
        return {"role": "assistant", "content": "Ollama não respondeu a tempo.", "tool_calls": None}
    except Exception as exc:
        logger.error("chat_with_tools error: %s", exc)
        return {"role": "assistant", "content": f"Erro: {exc}", "tool_calls": None}


class OllamaAdapter:
    """Class-based interface for Ollama provider."""

    def __init__(self, model: str | None = None):
        self.model = model

    async def generate(self, prompt: str, system_prompt: str | None = None, context: str | None = None) -> str:
        res = await generate_completion(
            prompt=prompt,
            system_prompt=system_prompt,
            context=context,
            model=self.model
        )
        return res.get("answer", "")

    async def generate_stream(self, prompt: str, system_prompt: str | None = None, context: str | None = None):
        async for chunk in generate_stream(
            prompt=prompt,
            system_prompt=system_prompt,
            context=context,
            model=self.model
        ):
            yield chunk

    async def chat_with_tools(
        self,
        messages: list[dict],
        tools: list[dict],
        model: str | None = None,
        temperature: float = 0.45,
    ) -> dict[str, Any]:
        return await chat_with_tools(
            messages=messages,
            tools=tools,
            model=model or self.model,
            temperature=temperature,
        )
