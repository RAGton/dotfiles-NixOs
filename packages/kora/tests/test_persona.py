"""
Tests for PersonaModulator and MindConstructor persona injection.

What is tested:
- PersonaModulator selects Engineer for debug-heavy queries.
- PersonaModulator selects Architect for design/architecture queries.
- PersonaModulator defaults to Engineer when no signals match.
- All persona dicts contain a non-empty style_directive.
- MindConstructor injects the persona style_directive into the synthesis
  system message (3rd LLM call).

What is NOT tested (subjective / out of scope):
- Whether the LLM output sounds "more technical" or "more strategic".
- Natural-language quality of the directive text itself.
"""
from __future__ import annotations

import asyncio
import json
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, patch


def _run(coro):
    loop = asyncio.new_event_loop()
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()


_PLAN_DEBUG_JSON = json.dumps({
    "sections": ["debugging", "log analysis"],
    "key_points": ["check journalctl for error"],
    "tone": "técnico",
    "confidence": 0.9,
})
_PLAN_ARCH_JSON = json.dumps({
    "sections": ["architecture overview", "trade-offs"],
    "key_points": ["modular pipeline design"],
    "tone": "analítico",
    "confidence": 0.85,
})
_CRITIQUE_JSON = json.dumps({
    "covers_query": True,
    "missing_points": [],
    "approved": True,
    "adjustments": "",
})
_SYNTHESIS_TEXT = "Resposta de síntese final para o teste de persona."


# ── PersonaModulator unit tests ───────────────────────────────────────────────

class TestPersonaModulator(unittest.TestCase):

    def _modulator(self):
        from kora.mind.persona import PersonaModulator
        return PersonaModulator()

    def _ctx(self, query: str, plan: dict | None = None, critique: dict | None = None):
        from kora.mind.persona import PersonaContext
        return PersonaContext(
            query=query,
            plan=plan or {"sections": [], "key_points": [], "tone": ""},
            critique=critique or {"approved": True, "missing_points": [], "adjustments": ""},
        )

    def test_engineer_selected_for_debug_query(self):
        """Queries containing error/debug/log keywords must select Engineer."""
        persona = self._modulator().get_persona(
            self._ctx("journalctl showing error after systemctl restart kora service")
        )
        self.assertEqual(persona.get("name"), "Engineer")

    def test_architect_selected_for_design_query(self):
        """Queries containing architecture/design/trade-off keywords must select Architect."""
        persona = self._modulator().get_persona(
            self._ctx("design the architecture for integrating ollama with the knowledge graph trade-off")
        )
        self.assertEqual(persona.get("name"), "Architect")

    def test_engineer_is_default_for_ambiguous_query(self):
        """When no signals match, the default Engineer persona must be returned."""
        persona = self._modulator().get_persona(self._ctx("hello kora"))
        self.assertEqual(persona.get("name"), "Engineer")

    def test_plan_sections_contribute_to_score(self):
        """Keywords in plan sections must also count towards persona selection."""
        from kora.mind.persona import PersonaContext
        ctx = PersonaContext(
            query="tell me about the system",
            plan={
                "sections": ["architecture overview", "migration strategy"],
                "key_points": ["modular design pattern"],
                "tone": "técnico",
            },
            critique={"approved": True, "missing_points": [], "adjustments": ""},
        )
        persona = self._modulator().get_persona(ctx)
        self.assertEqual(persona.get("name"), "Architect")

    def test_all_personas_have_style_directive(self):
        """Every persona defined in the manifest must have a non-empty style_directive."""
        from kora.mind.persona import PersonaModulator
        m = PersonaModulator()
        personas = m._manifest.get("personas", {})
        self.assertGreater(len(personas), 0, "Manifest must define at least one persona")
        for name, p in personas.items():
            self.assertIn(
                "style_directive", p,
                f"Persona '{name}' is missing style_directive",
            )
            self.assertGreater(
                len(p["style_directive"].strip()), 10,
                f"Persona '{name}' style_directive is too short",
            )

    def test_engineer_style_directive_contains_override_marker(self):
        """Engineer directive must contain the 'Style Override' marker."""
        ctx = self._ctx("debug error fix crash log")
        persona = self._modulator().get_persona(ctx)
        self.assertIn("Style Override", persona.get("style_directive", ""))

    def test_architect_style_directive_contains_override_marker(self):
        """Architect directive must contain the 'Style Override' marker."""
        ctx = self._ctx("design architecture trade-off migration refactor")
        persona = self._modulator().get_persona(ctx)
        self.assertIn("Style Override", persona.get("style_directive", ""))

    def test_builtin_fallback_returns_valid_manifest(self):
        """Built-in fallback manifest must define both Engineer and Architect."""
        from kora.mind.persona import _builtin_manifest
        manifest = _builtin_manifest()
        personas = manifest.get("personas", {})
        self.assertIn("engineer", personas)
        self.assertIn("architect", personas)
        self.assertEqual(manifest.get("default_persona"), "engineer")

    def test_missing_manifest_falls_back_gracefully(self):
        """PersonaModulator must not raise when the YAML file is absent."""
        from kora.mind.persona import PersonaModulator
        m = PersonaModulator(manifest_path=Path("/nonexistent/path/manifest.yaml"))
        persona = m.get_persona(self._ctx("any query"))
        self.assertIsNotNone(persona)
        self.assertIn("style_directive", persona)


# ── MindConstructor injection tests ──────────────────────────────────────────

class TestPersonaInjectionInMindConstructor(unittest.TestCase):
    """
    Verify that the style_directive reaches the synthesis LLM call.
    Strategy: capture all chat() calls and inspect the system message of call #3.
    """

    def _run_chain(self, query: str, plan_json: str) -> tuple[object, list[list[dict]]]:
        """
        Execute MindConstructor with captured LLM calls.
        Returns (MindResult, list_of_message_lists_per_call).
        """
        from kora.mind.constructor import MindConstructor

        captured: list[list[dict]] = []
        call_index = 0
        responses = [plan_json, _CRITIQUE_JSON, _SYNTHESIS_TEXT]

        async def capture_chat(messages, temperature=0.3, model=None):
            nonlocal call_index
            captured.append(list(messages))
            resp = responses[call_index % len(responses)]
            call_index += 1
            return {"answer": resp, "model": "test-model", "provider": "ollama"}

        mc = MindConstructor(session_id="persona-injection-test")

        async def run():
            with patch("kora.mind.constructor.chat", new=capture_chat):
                with patch("kora.mind.constructor._save_thought", new=AsyncMock()):
                    return await mc.execute(
                        query=query,
                        graph_context='[{"id": "kora-node"}]',
                    )

        result = _run(run())
        return result, captured

    def _get_synthesis_system(self, captured: list[list[dict]]) -> str:
        """Extract the system message content from the 3rd LLM call (synthesis)."""
        self.assertGreaterEqual(len(captured), 3, "Expected 3 LLM calls (plan/critique/synthesize)")
        synthesis_messages = captured[2]
        for msg in synthesis_messages:
            if msg.get("role") == "system":
                return msg["content"]
        return ""

    def test_engineer_directive_in_synthesis_system_message(self):
        """
        For a debug query, the synthesis system message must contain
        'Style Override' and 'Engineer'.
        """
        result, captured = self._run_chain(
            query="journalctl error debug fix kora service crash",
            plan_json=_PLAN_DEBUG_JSON,
        )
        system_content = self._get_synthesis_system(captured)

        self.assertIn(
            "Style Override", system_content,
            "Persona style_directive not injected into synthesis system message",
        )
        self.assertIn("Engineer", system_content)
        self.assertEqual(result.persona, "Engineer")

    def test_architect_directive_in_synthesis_system_message(self):
        """
        For a design query, the synthesis system message must contain
        'Style Override' and 'Architect'.
        """
        result, captured = self._run_chain(
            query="design the architecture trade-off integration pattern migration",
            plan_json=_PLAN_ARCH_JSON,
        )
        system_content = self._get_synthesis_system(captured)

        self.assertIn(
            "Style Override", system_content,
            "Persona style_directive not injected into synthesis system message",
        )
        self.assertIn("Architect", system_content)
        self.assertEqual(result.persona, "Architect")

    def test_directive_appended_after_system_prompt(self):
        """
        The persona directive must appear AFTER the base system_prompt,
        not replace it.
        """
        from kora.mind.constructor import MindConstructor

        captured: list[list[dict]] = []
        call_idx = 0
        responses = [_PLAN_DEBUG_JSON, _CRITIQUE_JSON, _SYNTHESIS_TEXT]

        async def capture_chat(messages, temperature=0.3, model=None):
            nonlocal call_idx
            captured.append(list(messages))
            resp = responses[call_idx % len(responses)]
            call_idx += 1
            return {"answer": resp, "model": "test-model", "provider": "ollama"}

        base_prompt = "Você é a Kora, assistente do Kryonix."
        mc = MindConstructor(session_id="order-test")

        async def run():
            with patch("kora.mind.constructor.chat", new=capture_chat):
                with patch("kora.mind.constructor._save_thought", new=AsyncMock()):
                    return await mc.execute(
                        query="debug error log fix",
                        graph_context='[{"id": "n1"}]',
                        system_prompt=base_prompt,
                    )

        _run(run())
        system_content = self._get_synthesis_system(captured)

        # Base prompt must still be present
        self.assertIn(base_prompt, system_content)
        # Directive must come after it
        base_pos = system_content.index(base_prompt)
        override_pos = system_content.index("Style Override")
        self.assertGreater(
            override_pos, base_pos,
            "Style Override directive must appear after the base system prompt",
        )

    def test_mindresult_carries_persona_name(self):
        """MindResult.persona must be the name string, not empty."""
        result, _ = self._run_chain(
            query="journalctl error crash fix",
            plan_json=_PLAN_DEBUG_JSON,
        )
        self.assertIn(result.persona, ("Engineer", "Architect"))
        self.assertGreater(len(result.persona), 0)


if __name__ == "__main__":
    unittest.main()
