from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Any

from kora.llm import ollama as ollama_adapter
from kora.llm.ollama import chat_with_turns

from .context import build_mind_context
from .dialogue_policy import get_dialogue_policy
from .persona import GOOD_CASUAL_CHECK_RESPONSE
from .reflection import KoraReflection

logger = logging.getLogger("kora.mind")


@dataclass
class MindInput:
    user_text: str
    normalized_text: str
    user_id: str
    identity_trust: str
    source: str
    intent: str
    conversation_history: list
    profile_context: str
    system_state: dict[str, Any]
    safety_context: dict[str, Any]

    @property
    def message(self) -> str:
        return self.user_text


@dataclass
class MindOutput:
    answer: str
    tone: str = "natural_direct"
    should_speak: bool = True
    memory_candidates: list = field(default_factory=list)
    needs_tool: bool = False
    tool_proposal: dict | None = None


class KoraMind:
    """LLM-centered response layer for Kora."""

    def __init__(self, llm_provider=None):
        self.llm_provider = llm_provider
        self.reflection = KoraReflection()

    async def respond(
        self,
        mind_input: MindInput,
        *,
        system_prompt: str,
        rag_context: str = "",
    ) -> MindOutput:
        policy = get_dialogue_policy(mind_input.intent)
        fast_answer = self._fast_path(mind_input)
        if fast_answer:
            reflected = self.reflection.review(
                mind_input.normalized_text,
                fast_answer,
                mind_input.intent,
                mind_input.safety_context,
            )
            return MindOutput(answer=reflected.answer, tone=policy.get("style", "natural_direct"))

        compact_context = build_mind_context(
            user_id=mind_input.user_id,
            identity_trust=mind_input.identity_trust,
            source=mind_input.source,
            intent=mind_input.intent,
            conversation_history=[],
            profile_context=mind_input.profile_context,
            system_state=mind_input.system_state,
            safety_context=mind_input.safety_context,
            dialogue_policy=policy,
            rag_context=rag_context,
        )

        user_message = f"{compact_context}\n\n{mind_input.message}"

        try:
            if self.llm_provider:
                if hasattr(self.llm_provider, "chat_with_turns"):
                    result = await self.llm_provider.chat_with_turns(
                        user_message=user_message,
                        system_prompt=system_prompt,
                        conversation_turns=mind_input.conversation_history,
                        context=rag_context,
                        temperature=0.45,
                    )
                else:
                    result = await self.llm_provider.generate(
                        prompt=user_message,
                        system_prompt=system_prompt,
                        context=rag_context,
                    )
                    if isinstance(result, str):
                        result = {"answer": result, "model": getattr(self.llm_provider, "model", None)}
                raw_answer = result.get("answer", "")
                model = result.get("model")
            else:
                result = await chat_with_turns(
                    user_message=user_message,
                    system_prompt=system_prompt,
                    conversation_turns=mind_input.conversation_history,
                    context=rag_context,
                    temperature=0.45,
                )
                raw_answer = result.get("answer", "")
                model = result.get("model")
            logger.debug("KoraMind generated answer with model=%s", model)
        except Exception as exc:
            logger.error("KoraMind generation failed: %s", exc)
            raw_answer = self._fallback(mind_input)

        reflected = self.reflection.review(
            mind_input.normalized_text,
            raw_answer,
            mind_input.intent,
            mind_input.safety_context,
        )
        return MindOutput(answer=reflected.answer, tone=policy.get("style", "natural_direct"))

    def _fast_path(self, mind_input: MindInput) -> str | None:
        if mind_input.intent == "casual_check":
            return GOOD_CASUAL_CHECK_RESPONSE

        if mind_input.intent == "capabilities_query":
            summary = mind_input.system_state.get("capabilities_summary")
            if summary:
                return summary

        return None

    def _fallback(self, mind_input: MindInput) -> str:
        if mind_input.intent == "casual_check":
            return GOOD_CASUAL_CHECK_RESPONSE
        return "Desculpe, meu modelo cognitivo não conseguiu gerar a resposta a tempo (Timeout no Ollama)."
