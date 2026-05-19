from __future__ import annotations

from dataclasses import dataclass

from .persona import BAD_CASUAL_CHECK_TERMS, GOOD_CASUAL_CHECK_RESPONSE


@dataclass
class ReflectionResult:
    passed: bool
    answer: str
    reason: str = ""


class KoraReflection:
    generic_phrases = []

    def review(self, user_text: str, answer: str, intent: str, safety_context: dict | None = None) -> ReflectionResult:
        clean_answer = (answer or "").strip()
        lower = clean_answer.lower()

        if intent == "casual_check":
            forbidden = [term for term in BAD_CASUAL_CHECK_TERMS if term.lower() in lower]
            if forbidden or "estou te ouvindo" not in lower:
                return ReflectionResult(
                    passed=False,
                    answer=GOOD_CASUAL_CHECK_RESPONSE,
                    reason="casual_check_repaired",
                )

        for phrase in self.generic_phrases:
            if phrase in lower:
                return ReflectionResult(
                    passed=False,
                    answer=self._fallback_for_intent(intent),
                    reason=f"generic_phrase:{phrase}",
                )

        if "reconheco sua voz biometricamente" in lower or "reconheço sua voz biometricamente" in lower:
            if not (safety_context or {}).get("speaker_id_ready", False):
                return ReflectionResult(
                    passed=False,
                    answer="Ainda nao biometricamente. Hoje eu uso identidade de sessao e perfil; Speaker ID real continua em foundation.",
                    reason="speaker_id_hallucination",
                )

        if "ja acordo" in lower or "já acordo" in lower or "wake-word esta pronto" in lower:
            if not (safety_context or {}).get("wake_word_ready", False):
                return ReflectionResult(
                    passed=False,
                    answer="Ainda nao. O wake-word Kora continua pendente de modelo validado; o caminho confiavel hoje e push-to-talk ou VAD.",
                    reason="wakeword_hallucination",
                )

        if len(clean_answer) < 8:
            return ReflectionResult(
                passed=False,
                answer=self._fallback_for_intent(intent),
                reason="too_short",
            )

        return ReflectionResult(passed=True, answer=clean_answer)

    def _fallback_for_intent(self, intent: str) -> str:
        if intent == "technical_diagnostic":
            return (
                "Diagnostico: a Kora ainda esta misturando roteamento tecnico com resposta humana.\n\n"
                "Correcao: normalizar a fala do Ragton, passar pelo KoraMind e validar com benchmark.\n\n"
                "Validacao: rodar `kora benchmark quality` e testar a frase casual de escuta."
            )
        if intent in {"complaint_bad_answer", "followup_complaint"}:
            return (
                "Voce tem razao. Minha resposta anterior ficou fraca.\n\n"
                "Diagnostico: faltou recuperar o contexto e responder ao ponto real.\n"
                "Correcao: vou usar o historico recente e refazer a resposta de forma direta.\n"
                "Validacao: o benchmark de reparo precisa cobrir esse caso."
            )
        return "Bom dia, Ragton! Estou pronta para ajudar, mesmo sem acesso à minha memória de longo prazo no momento."
