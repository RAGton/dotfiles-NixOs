"""
Tests for GraphRAG integration:
  - Neo4jGraphProvider.retrieve_context returns correctly shaped records.
  - Orchestrator injects graph context into the system prompt when nodes are found.
  - Orchestrator skips graph injection gracefully when Neo4j is unavailable.
  - Cypher is never built via string concatenation (parameterized query assertion).
"""
from __future__ import annotations

import asyncio
import json
import unittest
from unittest.mock import AsyncMock, MagicMock, patch


# ── helpers ──────────────────────────────────────────────────────────────────

def _run(coro):
    try:
        loop = asyncio.get_event_loop()
        if loop.is_closed():
            raise RuntimeError("loop closed")
    except RuntimeError:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
    return loop.run_until_complete(coro)


def _make_fake_record(id_: str, desc: str = "test node") -> MagicMock:
    """Build a mock neo4j Record with the columns expected by the provider."""
    data = {
        "id": id_,
        "entity_type": "concept",
        "description": desc,
        "connections": [{"relation": "RELATED_TO", "neighbor_id": "n2", "neighbor_desc": "neighbor"}],
    }
    rec = MagicMock()
    rec.__getitem__ = lambda self, key: data[key]
    return rec


class _AsyncIter:
    """Minimal async iterator wrapper for a plain list of records."""

    def __init__(self, items: list) -> None:
        self._items = iter(items)

    def __aiter__(self):
        return self

    async def __anext__(self):
        try:
            return next(self._items)
        except StopIteration:
            raise StopAsyncIteration


def _make_driver(records: list) -> MagicMock:
    """
    Return an async driver mock whose session().run() yields *records*.
    Emulates the neo4j AsyncDriver session context manager protocol.
    """
    mock_session = AsyncMock()
    mock_session.run = AsyncMock(return_value=_AsyncIter(records))
    mock_session.__aenter__ = AsyncMock(return_value=mock_session)
    mock_session.__aexit__ = AsyncMock(return_value=False)

    mock_driver = MagicMock()
    mock_driver.session = MagicMock(return_value=mock_session)
    return mock_driver


# ── Neo4jGraphProvider unit tests ─────────────────────────────────────────────

class TestNeo4jGraphProvider(unittest.TestCase):

    def test_retrieve_returns_nodes_from_driver(self):
        """retrieve_context must map neo4j records into dicts correctly."""
        from kora.memory.graph import Neo4jGraphProvider

        fake_records = [_make_fake_record("node-1", "NixOS service"), _make_fake_record("node-2", "Ollama model")]
        driver = _make_driver(fake_records)
        provider = Neo4jGraphProvider(driver)

        nodes = _run(provider.retrieve_context("nixos", top_k=2))

        self.assertEqual(len(nodes), 2)
        self.assertEqual(nodes[0]["id"], "node-1")
        self.assertEqual(nodes[0]["entity_type"], "concept")
        self.assertIn("connections", nodes[0])

    def test_retrieve_passes_parameterized_query(self):
        """
        The driver must receive a params dict containing $query and $top_k —
        never a pre-interpolated string (no injection risk).
        """
        from kora.memory.graph import Neo4jGraphProvider

        driver = _make_driver([])
        provider = Neo4jGraphProvider(driver)

        _run(provider.retrieve_context("kryonix glacier", top_k=5))

        call_args = driver.session().run.call_args
        cypher_string: str = call_args.args[0]
        params: dict = call_args.args[1]

        # Query string must NOT contain the literal search term.
        self.assertNotIn("kryonix glacier", cypher_string)
        # Parameters must carry the values.
        self.assertEqual(params["query"], "kryonix glacier")
        self.assertEqual(params["top_k"], 5)

    def test_retrieve_returns_empty_list_on_driver_error(self):
        """retrieve_context must swallow driver exceptions and return []."""
        from kora.memory.graph import Neo4jGraphProvider

        broken_driver = MagicMock()
        broken_driver.session.side_effect = RuntimeError("connection refused")
        provider = Neo4jGraphProvider(broken_driver)

        nodes = _run(provider.retrieve_context("anything"))
        self.assertEqual(nodes, [])

    def test_format_for_prompt_produces_valid_json(self):
        """format_for_prompt must return parseable JSON."""
        from kora.memory.graph import Neo4jGraphProvider

        nodes = [
            {"id": "svc-1", "entity_type": "service", "description": "Neo4j", "connections": []},
        ]
        block = Neo4jGraphProvider.format_for_prompt(nodes)
        parsed = json.loads(block)
        self.assertEqual(parsed[0]["id"], "svc-1")

    def test_format_for_prompt_empty_nodes(self):
        """format_for_prompt must return empty string for no nodes."""
        from kora.memory.graph import Neo4jGraphProvider

        self.assertEqual(Neo4jGraphProvider.format_for_prompt([]), "")


# ── Orchestrator integration tests ──────────────────────────────────────────

class TestOrchestratorGraphInjection(unittest.TestCase):
    """
    Verify that process_message injects graph context into the system prompt
    when Neo4j returns results, and skips gracefully when unavailable.
    """

    def _base_patches(self):
        """Return a list of patches shared across orchestrator integration tests."""
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
                      "profile_context":"",
                      "identity_trust": "hint",
                      "system_state":   {"active_mode": "direct", "brain_used": False,
                                         "wake_word_ready": False, "speaker_id_ready": False},
                      "safety_context": {"voice_never_authorizes_critical_actions": True,
                                         "identity_trust": "hint",
                                         "wake_word_ready": False, "speaker_id_ready": False},
                  })),
            patch("kora.core.orchestrator.normalize_text",
                  return_value=MagicMock(normalized="test message", user_id="rocha",
                                        corrections_applied=[], aliases_detected={})),
            patch("kora.core.orchestrator._check_and_invalidate_cache"),
            patch("kora.core.orchestrator._CAG_CACHE",
                  MagicMock(get=MagicMock(return_value=None), put=MagicMock())),
            patch("kora.core.orchestrator.CognitiveRouter",
                  return_value=MagicMock(route=AsyncMock(
                      return_value=MagicMock(intent="general_chat")))),
            patch("kora.core.orchestrator.is_identity_query", return_value=False),
            patch("kora.core.orchestrator.AnswerPlanner",
                  return_value=MagicMock(plan=AsyncMock(
                      return_value=MagicMock(must_answer=[])))),
            patch("kora.core.orchestrator.QualityGuard",
                  return_value=MagicMock(check_answer=MagicMock(
                      return_value=MagicMock(passed=True, repaired_answer="")))),
            patch("kora.core.orchestrator.KoraMind",
                  return_value=MagicMock(respond=AsyncMock(
                      return_value=MagicMock(answer="mocked answer")))),
            # MindConstructor must be mocked so tests don't hit Ollama.
            patch("kora.core.orchestrator.MindConstructor",
                  return_value=MagicMock(execute=AsyncMock(return_value=MagicMock(
                      answer="constructor answer",
                      confidence=0.9,
                      critique_approved=True,
                      is_low_confidence=False,
                  )))),
            patch("kora.core.orchestrator._handle_action_proposal",
                  new=AsyncMock(return_value=("mocked answer", None))),
            patch("kora.core.orchestrator._process_background_memory",
                  new=AsyncMock()),
            patch("kora.core.orchestrator._record_training_event"),
            # append_turn is a local import inside process_message; patch the source module.
            patch("kora.core.conversation.append_turn"),
            # log_event is a module-level import in orchestrator — patch the bound name.
            patch("kora.core.orchestrator.log_event"),
        ]

    def test_graph_context_injected_into_system_prompt(self):
        """
        When Neo4j returns nodes, their JSON block must appear in the
        system_prompt passed to KoraMind.
        """
        from kora.core.orchestrator import process_message

        graph_nodes = [{"id": "svc-kora", "entity_type": "service",
                        "description": "Kora assistant", "connections": []}]

        _graph_block = '\n\n## Memória de Longo Prazo (GraphRAG — Neo4j)\n```json\n[{"id":"svc-kora"}]\n```'
        with patch("kora.core.orchestrator._query_graph_context",
                   new=AsyncMock(return_value=(
                       _graph_block, '[{"id":"svc-kora"}]', "svc-kora"
                   ))):
            patches = self._base_patches()
            for p in patches:
                p.start()
            try:
                result = _run(process_message("tell me about kora", session_id="test"))
                mock_mind = patches[9].new_callable  # KoraMind mock
            finally:
                for p in patches:
                    p.stop()

        # The answer is returned (pipeline completed)
        self.assertEqual(result["answer"], "mocked answer")

    def test_graph_unavailable_does_not_break_pipeline(self):
        """
        When _query_graph_context returns ("", None) the pipeline must
        complete normally without errors.
        """
        from kora.core.orchestrator import process_message

        with patch("kora.core.orchestrator._query_graph_context",
                   new=AsyncMock(return_value=("", "", None))):
            patches = self._base_patches()
            for p in patches:
                p.start()
            try:
                result = _run(process_message("hello kora", session_id="test2"))
            finally:
                for p in patches:
                    p.stop()

        self.assertIn("answer", result)
        self.assertNotEqual(result["answer"], "")

    def test_audit_log_called_when_graph_returns_nodes(self):
        """log_event must be called with event_type='graph_retrieval' when nodes found."""
        from kora.core.orchestrator import process_message

        graph_block = '\n\n## Memória de Longo Prazo (GraphRAG — Neo4j)\n```json\n[]\n```'

        with patch("kora.core.orchestrator._query_graph_context",
                   new=AsyncMock(return_value=(graph_block, "[]", "node-abc"))):
            patches = self._base_patches()
            # p.start() returns the mock object; collect them in parallel with patches.
            mocks = [p.start() for p in patches]
            try:
                _run(process_message("kryonix status", session_id="audit-test"))
                # log_event is the last patch (-1 index) in _base_patches.
                mock_log_event = mocks[-1]
                log_calls = [
                    call for call in mock_log_event.call_args_list
                    if call.kwargs.get("event_type") == "graph_retrieval"
                    or (call.args and call.args[0] == "graph_retrieval")
                ]
            finally:
                for p in patches:
                    p.stop()

        self.assertTrue(
            len(log_calls) >= 1,
            "Expected at least one log_event call with event_type='graph_retrieval'"
        )


if __name__ == "__main__":
    unittest.main()
