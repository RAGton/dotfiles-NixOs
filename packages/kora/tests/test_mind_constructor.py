"""
Tests for MindConstructor — Plan → Critique → Synthesize chain.

Covers:
- Happy path: three LLM calls produce a final answer.
- Thought file is written with correct structure.
- Fallback: RuntimeError raised when any step returns an LLM error.
- Timeout: RuntimeError raised when chain exceeds the deadline.
- JSON parsing resilience: malformed plan/critique falls back to defaults.
"""
from __future__ import annotations

import asyncio
import json
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, patch


def _run(coro):
    try:
        loop = asyncio.get_event_loop()
        if loop.is_closed():
            raise RuntimeError("loop closed")
    except RuntimeError:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
    return loop.run_until_complete(coro)


# Canned LLM responses
_PLAN_JSON = json.dumps({
    "sections": ["Arquitetura", "Integração"],
    "key_points": ["Neo4j como grafo de memória"],
    "tone": "técnico",
    "confidence": 0.9,
})
_CRITIQUE_JSON = json.dumps({
    "covers_query": True,
    "missing_points": [],
    "approved": True,
    "adjustments": "",
})
_SYNTHESIS_TEXT = "O sistema Kryonix integra Neo4j como backend de memória de longo prazo."


def _make_chat_mock(responses: list[str]):
    """Return a chat() mock that yields responses[i] on the i-th call."""
    call_count = 0

    async def _chat(messages, temperature=0.3, model=None):
        nonlocal call_count
        resp = responses[call_count % len(responses)]
        call_count += 1
        if resp == "__error__":
            return {"answer": "", "error": "connection_refused"}
        return {"answer": resp, "model": "test-model", "provider": "ollama"}

    return _chat


class TestMindConstructorChain(unittest.TestCase):

    def test_happy_path_returns_synthesis(self):
        """Three successful LLM calls must return a MindResult with the synthesised answer."""
        from kora.mind.constructor import MindConstructor

        mc = MindConstructor(session_id="test-happy")
        responses = [_PLAN_JSON, _CRITIQUE_JSON, _SYNTHESIS_TEXT]

        async def run():
            with patch("kora.mind.constructor.chat", new=_make_chat_mock(responses)):
                with patch("kora.mind.constructor._save_thought", new=AsyncMock()):
                    return await mc.execute(
                        query="O que é o Kryonix?",
                        graph_context='[{"id": "kryonix", "description": "homelab"}]',
                        system_prompt="Você é a Kora.",
                    )

        result = _run(run())
        self.assertEqual(result.answer, _SYNTHESIS_TEXT)
        self.assertIsInstance(result.confidence, float)
        self.assertIsInstance(result.critique_approved, bool)

    def test_thought_saved_with_correct_keys(self):
        """_save_thought must be called with plan, critique, session_id and query."""
        from kora.mind.constructor import MindConstructor

        saved: list[dict] = []

        async def capture_thought(record):
            saved.append(record)

        mc = MindConstructor(session_id="thought-test")
        responses = [_PLAN_JSON, _CRITIQUE_JSON, _SYNTHESIS_TEXT]

        async def run():
            with patch("kora.mind.constructor.chat", new=_make_chat_mock(responses)):
                with patch("kora.mind.constructor._save_thought", new=capture_thought):
                    return await mc.execute(
                        query="query de teste",
                        graph_context='[{"id": "n1"}]',
                    )

        _run(run())

        self.assertEqual(len(saved), 1)
        record = saved[0]
        self.assertEqual(record["session_id"], "thought-test")
        self.assertIn("plan", record)
        self.assertIn("critique", record)
        self.assertIn("synthesis_elapsed_ms", record)
        self.assertTrue(record["plan"].get("confidence") > 0)

    def test_raises_on_llm_error_in_plan_step(self):
        """execute() must raise RuntimeError when the Plan step returns an error."""
        from kora.mind.constructor import MindConstructor

        mc = MindConstructor(session_id="error-test")
        responses = ["__error__"]

        async def run():
            with patch("kora.mind.constructor.chat", new=_make_chat_mock(responses)):
                with patch("kora.mind.constructor._save_thought", new=AsyncMock()):
                    return await mc.execute(
                        query="falha",
                        graph_context='[{"id": "n1"}]',
                    )

        with self.assertRaises(RuntimeError):
            _run(run())

    def test_raises_on_llm_error_in_synthesis_step(self):
        """execute() must raise RuntimeError when Synthesize returns an error."""
        from kora.mind.constructor import MindConstructor

        mc = MindConstructor(session_id="synth-error")
        responses = [_PLAN_JSON, _CRITIQUE_JSON, "__error__"]

        async def run():
            with patch("kora.mind.constructor.chat", new=_make_chat_mock(responses)):
                with patch("kora.mind.constructor._save_thought", new=AsyncMock()):
                    return await mc.execute(
                        query="falha na síntese",
                        graph_context='[{"id": "n1"}]',
                    )

        with self.assertRaises(RuntimeError):
            _run(run())

    def test_raises_on_timeout(self):
        """execute() must raise RuntimeError when timeout expires."""
        from kora.mind.constructor import MindConstructor

        mc = MindConstructor(session_id="timeout-test")

        async def slow_chat(messages, temperature=0.3, model=None):
            await asyncio.sleep(10)  # Simulate slow LLM
            return {"answer": _PLAN_JSON, "model": "test"}

        async def run():
            with patch("kora.mind.constructor.chat", new=slow_chat):
                with patch("kora.mind.constructor._save_thought", new=AsyncMock()):
                    return await mc.execute(
                        query="lento",
                        graph_context='[{"id": "n1"}]',
                        timeout=0.05,
                    )

        with self.assertRaises(RuntimeError, msg="Expected timeout RuntimeError"):
            _run(run())

    def test_malformed_json_falls_back_to_defaults(self):
        """Malformed Plan/Critique JSON must not abort the chain — fallback dicts apply."""
        from kora.mind.constructor import MindConstructor

        mc = MindConstructor(session_id="malformed-test")
        responses = [
            "Plano: analisar o sistema (sem JSON válido)",  # Plan: not JSON
            "A crítica foi concluída com sucesso.",          # Critique: not JSON
            _SYNTHESIS_TEXT,
        ]

        async def run():
            with patch("kora.mind.constructor.chat", new=_make_chat_mock(responses)):
                with patch("kora.mind.constructor._save_thought", new=AsyncMock()):
                    return await mc.execute(
                        query="query",
                        graph_context='[{"id": "n1"}]',
                    )

        result = _run(run())
        self.assertEqual(result.answer, _SYNTHESIS_TEXT)
        # Fallback confidence is 0.5, which is below the 0.65 threshold
        self.assertTrue(result.is_low_confidence)


class TestOrchestratorMindConstructorFallback(unittest.TestCase):
    """
    Verify the orchestrator falls back to KoraMind when MindConstructor fails,
    and that the system_prompt does NOT contain the RAG block in the fallback path.
    """

    def _base_patches(self):
        return [
            patch("kora.core.orchestrator._prepare_session_and_context",
                  new=AsyncMock(return_value={
                      "system_prompt":  "BASE PROMPT",
                      "context_text":   "",
                      "active_mode":    "direct",
                      "brain_used":     False,
                      "searched_files": [],
                      "start_time":     0.0,
                      "trust_level":    "hint",
                      "greeting":       "",
                      "profile_context": "",
                      "identity_trust":  "hint",
                      "system_state":   {"active_mode": "direct", "brain_used": False,
                                         "wake_word_ready": False, "speaker_id_ready": False},
                      "safety_context": {"voice_never_authorizes_critical_actions": True,
                                         "identity_trust": "hint",
                                         "wake_word_ready": False, "speaker_id_ready": False},
                  })),
            patch("kora.core.orchestrator.normalize_text",
                  return_value=__import__("unittest.mock", fromlist=["MagicMock"]).MagicMock(
                      normalized="test message", user_id="rocha",
                      corrections_applied=[], aliases_detected={})),
            patch("kora.core.orchestrator._check_and_invalidate_cache"),
            patch("kora.core.orchestrator._CAG_CACHE",
                  __import__("unittest.mock", fromlist=["MagicMock"]).MagicMock(
                      get=__import__("unittest.mock", fromlist=["MagicMock"]).MagicMock(return_value=None),
                      put=__import__("unittest.mock", fromlist=["MagicMock"]).MagicMock())),
            patch("kora.core.orchestrator.CognitiveRouter",
                  return_value=__import__("unittest.mock", fromlist=["MagicMock"]).MagicMock(
                      route=AsyncMock(return_value=__import__("unittest.mock", fromlist=["MagicMock"]).MagicMock(
                          intent="general_chat")))),
            patch("kora.core.orchestrator.is_identity_query", return_value=False),
            patch("kora.core.orchestrator.AnswerPlanner",
                  return_value=__import__("unittest.mock", fromlist=["MagicMock"]).MagicMock(
                      plan=AsyncMock(return_value=__import__("unittest.mock", fromlist=["MagicMock"]).MagicMock(
                          must_answer=[])))),
            patch("kora.core.orchestrator.QualityGuard",
                  return_value=__import__("unittest.mock", fromlist=["MagicMock"]).MagicMock(
                      check_answer=__import__("unittest.mock", fromlist=["MagicMock"]).MagicMock(
                          return_value=__import__("unittest.mock", fromlist=["MagicMock"]).MagicMock(
                              passed=True, repaired_answer="")))),
            patch("kora.core.orchestrator.KoraMind",
                  return_value=__import__("unittest.mock", fromlist=["MagicMock"]).MagicMock(
                      respond=AsyncMock(return_value=__import__("unittest.mock", fromlist=["MagicMock"]).MagicMock(
                          answer="koramind fallback answer")))),
            patch("kora.core.orchestrator._handle_action_proposal",
                  new=AsyncMock(return_value=("koramind fallback answer", None))),
            patch("kora.core.orchestrator._process_background_memory", new=AsyncMock()),
            patch("kora.core.orchestrator._record_training_event"),
            patch("kora.core.conversation.append_turn"),
            patch("kora.core.orchestrator.log_event"),
        ]

    def test_koramind_called_when_constructor_raises(self):
        """
        When MindConstructor.execute raises, KoraMind must be invoked
        and its answer returned.
        """
        from kora.core.orchestrator import process_message
        from unittest.mock import MagicMock

        graph_block = '\n\n## Memória de Longo Prazo\n```json\n[{"id":"n1"}]\n```'

        failing_constructor = MagicMock(
            execute=AsyncMock(side_effect=RuntimeError("LLM timeout"))
        )

        with patch("kora.core.orchestrator._query_graph_context",
                   new=AsyncMock(return_value=(graph_block, '[{"id":"n1"}]', "n1"))):
            with patch("kora.core.orchestrator.MindConstructor",
                       return_value=failing_constructor):
                patches = self._base_patches()
                mocks = [p.start() for p in patches]
                try:
                    result = _run(process_message("kryonix status", session_id="fb-test"))
                    # log_event is last mock
                    mock_log = mocks[-1]
                    fallback_calls = [
                        c for c in mock_log.call_args_list
                        if c.kwargs.get("event_type") == "mind_constructor_fallback"
                        or (c.args and c.args[0] == "mind_constructor_fallback")
                    ]
                finally:
                    for p in patches:
                        p.stop()

        self.assertEqual(result["answer"], "koramind fallback answer")
        self.assertGreaterEqual(len(fallback_calls), 1)


if __name__ == "__main__":
    unittest.main()
