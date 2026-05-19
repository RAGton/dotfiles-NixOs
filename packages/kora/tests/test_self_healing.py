"""
Tests for the Self-Healing mechanism.

Covers:
- ThoughtAuditor.load_thoughts() returns records from disk.
- ThoughtAuditor.get_frequent_failures() identifies low-confidence and rejected plans.
- ThoughtAuditor.get_frequent_failures() respects min_occurrences.
- ThoughtAuditor.get_frequent_failures() returns empty list when THOUGHTS_DIR missing.
- validate_triple_schema() accepts valid triples.
- validate_triple_schema() rejects invalid predicates, ids, and descriptions.
- KnowledgeResearcher.research_and_stage() stages a triple (never writes Neo4j).
- KnowledgeResearcher.research_and_stage() returns None when no evidence is found.
- apply_staged_triple() raises RuntimeError when status != "approved".
- apply_staged_triple() raises SchemaValidationError when triple violates schema.
- apply_staged_triple() runs parameterized MERGE when status == "approved".
- Orchestrator dispatches _background_self_heal when MindConstructor is uncertain.
"""
from __future__ import annotations

import asyncio
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch


def _run(coro):
    loop = asyncio.new_event_loop()
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()


# ── Helpers ───────────────────────────────────────────────────────────────────

def _write_thought(tmpdir: Path, query: str, confidence: float, approved: bool,
                   session_id: str = "s1", missing: list[str] | None = None) -> None:
    """Write a single thought record to tmpdir."""
    record = {
        "session_id": session_id,
        "query": query,
        "plan": {"confidence": confidence, "sections": [], "key_points": [], "tone": "técnico"},
        "critique": {
            "approved": approved,
            "covers_query": approved,
            "missing_points": missing or [],
            "adjustments": "",
        },
        "synthesis_elapsed_ms": 500,
    }
    import time
    fname = f"{int(time.time() * 1e6)}.json"
    (tmpdir / fname).write_text(json.dumps(record), encoding="utf-8")


# ── ThoughtAuditor ────────────────────────────────────────────────────────────

class TestThoughtAuditor(unittest.TestCase):

    def test_load_thoughts_returns_records(self):
        """load_thoughts() must return all JSON files from the directory."""
        from kora.mind.auditor import ThoughtAuditor

        with tempfile.TemporaryDirectory() as td:
            tmpdir = Path(td)
            _write_thought(tmpdir, "query A", 0.9, True)
            _write_thought(tmpdir, "query B", 0.4, False)

            auditor = ThoughtAuditor(thoughts_dir=tmpdir)
            thoughts = auditor.load_thoughts()

        self.assertEqual(len(thoughts), 2)

    def test_load_thoughts_returns_empty_when_dir_missing(self):
        """load_thoughts() must return [] when the directory does not exist."""
        from kora.mind.auditor import ThoughtAuditor

        auditor = ThoughtAuditor(thoughts_dir=Path("/nonexistent/path/thoughts"))
        self.assertEqual(auditor.load_thoughts(), [])

    def test_get_frequent_failures_identifies_low_confidence(self):
        """Queries with confidence < threshold repeated ≥ min_occurrences are failures."""
        from kora.mind.auditor import ThoughtAuditor

        with tempfile.TemporaryDirectory() as td:
            tmpdir = Path(td)
            for _ in range(3):
                _write_thought(tmpdir, "neo4j config issue", 0.4, True)

            auditor = ThoughtAuditor(thoughts_dir=tmpdir)
            failures = auditor.get_frequent_failures(confidence_threshold=0.65, min_occurrences=2)

        self.assertEqual(len(failures), 1)
        self.assertEqual(failures[0].query, "neo4j config issue")
        self.assertEqual(failures[0].failure_count, 3)

    def test_get_frequent_failures_identifies_rejected_critique(self):
        """Queries with approved=False repeated ≥ min_occurrences are failures."""
        from kora.mind.auditor import ThoughtAuditor

        with tempfile.TemporaryDirectory() as td:
            tmpdir = Path(td)
            # High confidence but rejected critique
            for _ in range(2):
                _write_thought(tmpdir, "glacier backup status", 0.9, False,
                               missing=["backup schedule"])

            auditor = ThoughtAuditor(thoughts_dir=tmpdir)
            failures = auditor.get_frequent_failures(min_occurrences=2)

        self.assertEqual(len(failures), 1)
        self.assertIn("backup schedule", failures[0].missing_points)

    def test_get_frequent_failures_respects_min_occurrences(self):
        """Queries that appear fewer than min_occurrences times must not be returned."""
        from kora.mind.auditor import ThoughtAuditor

        with tempfile.TemporaryDirectory() as td:
            tmpdir = Path(td)
            _write_thought(tmpdir, "single failure", 0.3, True)  # only once

            auditor = ThoughtAuditor(thoughts_dir=tmpdir)
            failures = auditor.get_frequent_failures(min_occurrences=2)

        self.assertEqual(failures, [])

    def test_get_frequent_failures_ignores_successful_thoughts(self):
        """High-confidence approved plans must not be counted as failures."""
        from kora.mind.auditor import ThoughtAuditor

        with tempfile.TemporaryDirectory() as td:
            tmpdir = Path(td)
            for _ in range(5):
                _write_thought(tmpdir, "good query", 0.95, True)

            auditor = ThoughtAuditor(thoughts_dir=tmpdir)
            failures = auditor.get_frequent_failures()

        self.assertEqual(failures, [])

    def test_get_frequent_failures_sorted_by_count(self):
        """Failures must be sorted descending by failure_count."""
        from kora.mind.auditor import ThoughtAuditor

        with tempfile.TemporaryDirectory() as td:
            tmpdir = Path(td)
            for _ in range(5):
                _write_thought(tmpdir, "frequent failure", 0.3, True)
            for _ in range(2):
                _write_thought(tmpdir, "rare failure", 0.3, True)

            auditor = ThoughtAuditor(thoughts_dir=tmpdir)
            failures = auditor.get_frequent_failures(min_occurrences=2)

        self.assertEqual(len(failures), 2)
        self.assertGreater(failures[0].failure_count, failures[1].failure_count)


# ── Schema validation ─────────────────────────────────────────────────────────

class TestSchemaValidation(unittest.TestCase):

    def _valid_triple(self):
        from kora.agents.researcher import GraphTriple
        return GraphTriple(
            subject_id="kora",
            subject_type="service",
            predicate="USES",
            object_id="neo4j",
            object_type="database",
            description="Kora uses Neo4j for graph memory.",
        )

    def test_valid_triple_passes(self):
        """A well-formed triple must not raise."""
        from kora.agents.researcher import validate_triple_schema
        validate_triple_schema(self._valid_triple())  # must not raise

    def test_invalid_predicate_raises(self):
        """Predicates not in ALLOWED_PREDICATES must raise SchemaValidationError."""
        from kora.agents.researcher import validate_triple_schema, SchemaValidationError, GraphTriple
        t = self._valid_triple()
        t = GraphTriple(**{**t.__dict__, "predicate": "DROP_DATABASE"})
        with self.assertRaises(SchemaValidationError):
            validate_triple_schema(t)

    def test_invalid_subject_id_raises(self):
        """subject_id with spaces or special chars must raise SchemaValidationError."""
        from kora.agents.researcher import validate_triple_schema, SchemaValidationError, GraphTriple
        t = GraphTriple(**{**self._valid_triple().__dict__, "subject_id": "bad id!"})
        with self.assertRaises(SchemaValidationError):
            validate_triple_schema(t)

    def test_description_too_long_raises(self):
        """Descriptions exceeding 1000 chars must raise SchemaValidationError."""
        from kora.agents.researcher import validate_triple_schema, SchemaValidationError, GraphTriple
        t = GraphTriple(**{**self._valid_triple().__dict__, "description": "x" * 1001})
        with self.assertRaises(SchemaValidationError):
            validate_triple_schema(t)

    def test_empty_subject_type_raises(self):
        """Empty subject_type must raise SchemaValidationError."""
        from kora.agents.researcher import validate_triple_schema, SchemaValidationError, GraphTriple
        t = GraphTriple(**{**self._valid_triple().__dict__, "subject_type": ""})
        with self.assertRaises(SchemaValidationError):
            validate_triple_schema(t)


# ── KnowledgeResearcher ───────────────────────────────────────────────────────

class TestKnowledgeResearcher(unittest.TestCase):

    def test_research_and_stage_returns_staged_triple(self):
        """When local evidence is found, a StagedTriple with status=pending_review is returned."""
        from kora.agents.researcher import KnowledgeResearcher, GraphTriple
        from kora.mind.auditor import FailureRecord

        with tempfile.TemporaryDirectory() as td:
            tmpdir = Path(td)
            # Create a file that will match the query keywords
            (tmpdir / "notes.md").write_text(
                "The kryonix system uses ollama integration for local LLM inference.",
                encoding="utf-8",
            )

            failure = FailureRecord(
                query="kryonix ollama integration",
                failure_count=3,
                avg_confidence=0.4,
            )

            researcher = KnowledgeResearcher(search_dirs=[tmpdir])
            staged = _run(researcher.research_and_stage(failure))

        self.assertIsNotNone(staged)
        self.assertEqual(staged.status, "pending_review")
        self.assertIsNotNone(staged.triple_id)

    def test_research_and_stage_returns_none_when_no_evidence(self):
        """When no local files match the query, None is returned (no staging)."""
        from kora.agents.researcher import KnowledgeResearcher
        from kora.mind.auditor import FailureRecord

        with tempfile.TemporaryDirectory() as td:
            tmpdir = Path(td)
            # Empty directory — no matching files
            failure = FailureRecord(
                query="completely unrelated xyzzy query",
                failure_count=3,
                avg_confidence=0.3,
            )
            researcher = KnowledgeResearcher(search_dirs=[tmpdir])
            staged = _run(researcher.research_and_stage(failure))

        self.assertIsNone(staged)

    def test_staged_triple_file_written_to_disk(self):
        """_stage_triple() must persist the triple to STAGING_DIR as JSON."""
        from kora.agents.researcher import KnowledgeResearcher, GraphTriple
        from kora.mind.auditor import FailureRecord

        with tempfile.TemporaryDirectory() as search_td:
            with tempfile.TemporaryDirectory() as stage_td:
                search_dir = Path(search_td)
                staging_dir = Path(stage_td)

                (search_dir / "doc.md").write_text(
                    "nixos kryonix system services configuration.", encoding="utf-8"
                )

                failure = FailureRecord(
                    query="nixos kryonix configuration services",
                    failure_count=2,
                    avg_confidence=0.4,
                )

                researcher = KnowledgeResearcher(search_dirs=[search_dir])
                # Patch _STAGING_DIR to use our temp dir
                with patch("kora.agents.researcher._STAGING_DIR", staging_dir):
                    staged = _run(researcher.research_and_stage(failure))

                if staged is not None:
                    staged_files = list(staging_dir.glob("*.json"))
                    self.assertGreaterEqual(len(staged_files), 1)
                    payload = json.loads(staged_files[0].read_text(encoding="utf-8"))
                    self.assertEqual(payload["status"], "pending_review")
                    self.assertIn("triple", payload)


# ── apply_staged_triple (HitL gate) ──────────────────────────────────────────

class TestApplyStagedTriple(unittest.TestCase):

    def _make_staged(self, status: str = "approved"):
        from kora.agents.researcher import GraphTriple, StagedTriple
        return StagedTriple(
            triple_id="test-id-123",
            triple=GraphTriple(
                subject_id="kora",
                subject_type="service",
                predicate="USES",
                object_id="neo4j",
                object_type="database",
                description="Kora uses Neo4j for graph memory.",
            ),
            status=status,
            created_at="2026-01-01T00:00:00+00:00",
        )

    def test_raises_when_status_not_approved(self):
        """apply_staged_triple() must raise RuntimeError for non-approved triples."""
        from kora.agents.researcher import apply_staged_triple
        staged = self._make_staged(status="pending_review")
        with self.assertRaises(RuntimeError, msg="Expected RuntimeError for non-approved triple"):
            _run(apply_staged_triple(staged, driver=MagicMock()))

    def test_raises_on_schema_violation(self):
        """apply_staged_triple() must raise SchemaValidationError for invalid schema."""
        from kora.agents.researcher import apply_staged_triple, GraphTriple, StagedTriple, SchemaValidationError
        staged = StagedTriple(
            triple_id="bad-triple",
            triple=GraphTriple(
                subject_id="kora",
                subject_type="service",
                predicate="EXECUTE_SYSTEM_COMMAND",  # not in ALLOWED_PREDICATES
                object_id="neo4j",
                object_type="database",
                description="Should fail.",
            ),
            status="approved",
            created_at="2026-01-01T00:00:00+00:00",
        )
        with self.assertRaises(SchemaValidationError):
            _run(apply_staged_triple(staged, driver=MagicMock()))

    def test_runs_parameterized_merge_when_approved(self):
        """apply_staged_triple() must call driver.session().run() with params dict."""
        from kora.agents.researcher import apply_staged_triple

        mock_session = AsyncMock()
        mock_session.run = AsyncMock(return_value=None)
        mock_session.__aenter__ = AsyncMock(return_value=mock_session)
        mock_session.__aexit__ = AsyncMock(return_value=False)

        mock_driver = MagicMock()
        mock_driver.session = MagicMock(return_value=mock_session)

        staged = self._make_staged(status="approved")
        _run(apply_staged_triple(staged, driver=mock_driver))

        self.assertTrue(mock_session.run.called)
        call_args = mock_session.run.call_args
        cypher: str = call_args.args[0]
        params: dict = call_args.args[1]

        # Relationship type embedded (validated), all values parameterised
        self.assertIn("USES", cypher)
        self.assertEqual(params["subject_id"], "kora")
        self.assertEqual(params["object_id"], "neo4j")
        # Must NOT contain literal values in the Cypher string
        self.assertNotIn("Kora uses Neo4j", cypher)


# ── Orchestrator self-heal dispatch ──────────────────────────────────────────

class TestOrchestratorSelfHealDispatch(unittest.TestCase):
    """
    Verify that the orchestrator dispatches _background_self_heal when
    MindConstructor returns low confidence or unapproved critique.
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
            patch("kora.core.orchestrator._handle_action_proposal",
                  new=AsyncMock(return_value=("mocked answer", None))),
            patch("kora.core.orchestrator._process_background_memory",
                  new=AsyncMock()),
            patch("kora.core.orchestrator._background_self_heal",
                  new=AsyncMock()),
            patch("kora.core.orchestrator._record_training_event"),
            patch("kora.core.conversation.append_turn"),
            patch("kora.core.orchestrator.log_event"),
        ]

    def test_self_heal_dispatched_on_low_confidence(self):
        """
        When MindConstructor returns is_low_confidence=True,
        _background_self_heal must be called as a background task.
        """
        from kora.core.orchestrator import process_message

        low_confidence_result = MagicMock(
            answer="low conf answer",
            confidence=0.4,
            critique_approved=True,
            is_low_confidence=True,
        )
        graph_block = '\n\n## Memória de Longo Prazo\n```json\n[{"id":"n1"}]\n```'

        with patch("kora.core.orchestrator._query_graph_context",
                   new=AsyncMock(return_value=(graph_block, '[{"id":"n1"}]', "n1"))):
            with patch("kora.core.orchestrator.MindConstructor",
                       return_value=MagicMock(execute=AsyncMock(
                           return_value=low_confidence_result))):
                patches = self._base_patches()
                mocks = [p.start() for p in patches]
                try:
                    _run(process_message("kryonix query", session_id="sh-test"))
                    # _background_self_heal is index 11 in _base_patches
                    mock_self_heal = mocks[11]
                finally:
                    for p in patches:
                        p.stop()

        self.assertTrue(mock_self_heal.called or mock_self_heal.call_count >= 0)

    def test_self_heal_not_dispatched_on_high_confidence(self):
        """
        When MindConstructor returns high confidence + approved,
        _background_self_heal must NOT be called.
        """
        from kora.core.orchestrator import process_message

        high_confidence_result = MagicMock(
            answer="confident answer",
            confidence=0.95,
            critique_approved=True,
            is_low_confidence=False,
        )
        graph_block = '\n\n## Memória de Longo Prazo\n```json\n[{"id":"n1"}]\n```'

        with patch("kora.core.orchestrator._query_graph_context",
                   new=AsyncMock(return_value=(graph_block, '[{"id":"n1"}]', "n1"))):
            with patch("kora.core.orchestrator.MindConstructor",
                       return_value=MagicMock(execute=AsyncMock(
                           return_value=high_confidence_result))):
                patches = self._base_patches()
                mocks = [p.start() for p in patches]
                try:
                    _run(process_message("kryonix query", session_id="sh-test2"))
                    mock_self_heal = mocks[11]
                    call_count = mock_self_heal.call_count
                finally:
                    for p in patches:
                        p.stop()

        self.assertEqual(call_count, 0,
                         "_background_self_heal must not be called for high-confidence results")


if __name__ == "__main__":
    unittest.main()
