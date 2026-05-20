import json
import logging
import re
from dataclasses import dataclass
from typing import Optional

from kora.llm.ollama import OllamaAdapter

logger = logging.getLogger("kora.core.router")

class Intent:
    GREETING = "greeting"
    CASUAL_CHECK = "casual_check"
    IDENTITY_QUERY = "identity_query"
    CAPABILITIES_QUERY = "capabilities_query"
    FOLLOWUP_COMPLAINT = "followup_complaint"
    COMPLAINT_BAD_ANSWER = "complaint_bad_answer"
    TECHNICAL_DIAGNOSTIC = "technical_diagnostic"
    LEARNING_REQUEST = "learning_request"
    PROJECT_KNOWLEDGE = "project_knowledge"
    SYSTEM_STATUS = "system_status"
    COMMAND_EXPLAIN = "command_explain"
    COMMAND_EXECUTE = "command_execute"
    MEMORY_QUERY = "memory_query"
    MEMORY_CAPTURE = "memory_capture"
    VOICE_STATUS = "voice_status"
    AUTOMATION_N8N = "automation_n8n"
    TIME_QUERY = "time_query"
    GENERAL_CHAT = "general_chat"

@dataclass
class RouteResult:
    intent: str
    confidence: float
    requires_rag: bool
    requires_tool: bool
    requires_status_check: bool
    risk: str
    reason: str

class CognitiveRouter:
    """Classifies user intent before reaching the main Answer Planner / Orchestrator."""

    def __init__(self, llm_provider=None):
        self.llm = llm_provider or OllamaAdapter()
        self.system_prompt = self._build_prompt()

    def _build_prompt(self) -> str:
        return """Você é o roteador cognitivo da Kora.
Sua única função é ler a entrada do usuário e classificá-la em uma das intenções disponíveis.

## Intenções:
- greeting: Saudações simples ("olá", "bom dia", "oi Kora")
- casual_check: Perguntas casuais de escuta/presenca ("voce esta me ouvindo?", "ta me ouvindo?")
- identity_query: Perguntas sobre identidade ("quem sou eu", "você me conhece")
- capabilities_query: Perguntas sobre capacidades ("o que você pode fazer", "quais suas funções")
- followup_complaint: Reclamações sobre a resposta anterior ("você não respondeu", "minha pergunta anterior")
- complaint_bad_answer: Reclamações sobre resposta ruim ou pergunta ignorada
- technical_diagnostic: Pedidos de pente fino, auditoria tecnica ou diagnostico da Kora/Kryonix
- learning_request: Pedidos para aprender estilo, corrigir transcricao, registrar alias ou melhorar entendimento
- project_knowledge: Dúvidas sobre arquitetura, conceitos ou documentação do Kryonix ("qual a arquitetura do Glacier")
- system_status: Perguntas sobre status de serviços ("como está o Ollama", "status do tailscale")
- command_explain: Pedidos para explicar um comando ("explique kryonix switch all")
- command_execute: Pedidos para executar ações ou comandos reais no sistema
- memory_query: Consultar memórias passadas ("você lembra o que eu falei")
- memory_capture: Pedido explícito para guardar/anotar algo ("anote que eu gosto de café")
- voice_status: Perguntas tecnicas explicitas sobre stack de voz ("status do STT", "o wake-word está ativo?", "diagnostico do TTS")
- automation_n8n: Pedidos de automação, lembretes, fluxos
- general_chat: Bate-papo genérico ou perguntas que não se encaixam acima

Responda ÚNICA e EXCLUSIVAMENTE em JSON válido, com esta estrutura:
{
  "intent": "<UMA_DAS_INTENCOES_ACIMA>",
  "confidence": <FLOAT_0_A_1>,
  "requires_rag": <BOOLEAN>,
  "requires_tool": <BOOLEAN>,
  "requires_status_check": <BOOLEAN>,
  "risk": "<read_only, medium, high>",
  "reason": "<Breve explicação da classificação>"
}
Não inclua texto fora do JSON.
"""

    async def route(self, text: str) -> RouteResult:
        # Trivial deterministic matching for extreme speed on obvious cases
        lower_text = text.lower().strip()

        time_query_patterns = [
            "que horas", "que hora", "horas são", "hora é",
            "hora atual", "hora certa", "me diz as horas",
            "que dia é hoje", "data de hoje", "qual a data",
            "data atual", "hoje é dia", "que dia é",
            "que horas são agora", "qual a hora",
        ]
        if any(pattern in lower_text for pattern in time_query_patterns):
            return RouteResult(
                intent=Intent.TIME_QUERY,
                confidence=1.0,
                requires_rag=False,
                requires_tool=False,
                requires_status_check=False,
                risk="read_only",
                reason="Deterministic match for time/date query — answered by system clock"
            )

        casual_check_patterns = [
            "voce esta me ouvindo",
            "você está me ouvindo",
            "voce me ouve",
            "você me ouve",
            "ta me ouvindo",
            "tá me ouvindo",
            "me escuta",
            "voce me escuta",
            "você me escuta",
            "esta me ouvindo agora",
            "está me ouvindo agora",
        ]
        if any(pattern in lower_text for pattern in casual_check_patterns):
            return RouteResult(
                intent=Intent.CASUAL_CHECK,
                confidence=1.0,
                requires_rag=False,
                requires_tool=False,
                requires_status_check=False,
                risk="read_only",
                reason="Deterministic match for casual listening check"
            )

        diagnostic_patterns = [
            "pente fino",
            "pentifino",
            "auditoria tecnica",
            "auditoria técnica",
            "diagnostico",
            "diagnóstico",
        ]
        if any(pattern in lower_text for pattern in diagnostic_patterns) and ("kora" in lower_text or "kryonix" in lower_text):
            return RouteResult(
                intent=Intent.TECHNICAL_DIAGNOSTIC,
                confidence=0.98,
                requires_rag=False,
                requires_tool=False,
                requires_status_check=False,
                risk="read_only",
                reason="Deterministic match for technical diagnostic"
            )

        learning_patterns = [
            "aprenda",
            "lembra que eu falo",
            "corrige quando eu falar",
            "adicione correcao",
            "adicione correção",
            "registre alias",
            "meu jeito de falar",
        ]
        if any(pattern in lower_text for pattern in learning_patterns):
            return RouteResult(
                intent=Intent.LEARNING_REQUEST,
                confidence=0.95,
                requires_rag=False,
                requires_tool=False,
                requires_status_check=False,
                risk="read_only",
                reason="Deterministic match for learning request"
            )

        voice_status_patterns = [
            "status do stt",
            "status do tts",
            "wake-word",
            "wake word",
            "acorda quando eu falo kora",
            "reconhece minha voz",
            "speaker id",
            "biometricamente",
        ]
        if any(pattern in lower_text for pattern in voice_status_patterns):
            return RouteResult(
                intent=Intent.VOICE_STATUS,
                confidence=0.95,
                requires_rag=False,
                requires_tool=False,
                requires_status_check=True,
                risk="read_only",
                reason="Deterministic match for explicit voice status"
            )
        
        bad_answer_triggers = ["respondeu ruim", "ignorou minha pergunta", "resposta ruim", "respondeu errado", "não está entendendo", "nao esta entendendo"]
        for trigger in bad_answer_triggers:
            if trigger in lower_text:
                return RouteResult(
                    intent=Intent.COMPLAINT_BAD_ANSWER,
                    confidence=0.95,
                    requires_rag=False,
                    requires_tool=False,
                    requires_status_check=False,
                    risk="read_only",
                    reason="Deterministic match for bad answer complaint"
                )

        followup_triggers = ["você não respondeu", "voce nao respondeu", "não respondeu minha pergunta", "nao respondeu minha pergunta", "você ignorou", "voce ignorou", "você lembra o que eu falei", "voce lembra o que eu falei", "eu perguntei outra coisa", "você não entendeu", "voce nao entendeu", "fugindo da pergunta"]
        for trigger in followup_triggers:
            if trigger in lower_text:
                return RouteResult(
                    intent=Intent.FOLLOWUP_COMPLAINT,
                    confidence=0.95,
                    requires_rag=False,
                    requires_tool=False,
                    requires_status_check=False,
                    risk="read_only",
                    reason="Deterministic match for followup complaint"
                )

        capabilities_triggers = ["o que você pode fazer", "o que a gente pode fazer", "o que você consegue fazer", "quais as suas funções", "suas capacidades", "o que consegue fazer"]
        for trigger in capabilities_triggers:
            if trigger in lower_text:
                return RouteResult(
                    intent=Intent.CAPABILITIES_QUERY,
                    confidence=1.0,
                    requires_rag=False,
                    requires_tool=False,
                    requires_status_check=False,
                    risk="read_only",
                    reason="Deterministic match for capabilities"
                )

        if lower_text in ["quem sou eu?", "quem sou eu", "você sabe quem eu sou?", "quem está falando?"]:
            return RouteResult(
                intent=Intent.IDENTITY_QUERY,
                confidence=1.0,
                requires_rag=False,
                requires_tool=False,
                requires_status_check=False,
                risk="read_only",
                reason="Deterministic identity query"
            )

        # Fallback immediately to avoid network call latency
        return RouteResult(
            intent=Intent.GENERAL_CHAT,
            confidence=0.5,
            requires_rag=False,
            requires_tool=False,
            requires_status_check=False,
            risk="read_only",
            reason="Fallback to general chat to reduce latency"
        )
