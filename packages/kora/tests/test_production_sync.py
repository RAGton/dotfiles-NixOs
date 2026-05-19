"""
Production smoke tests for `kora brain sync`.

- ``TestBrainSyncCLI``  runs always: mock-based, verifies handler wiring,
  dry-run isolation (no Neo4j connection attempt), and exit-code contract.
- ``TestBrainSyncLive`` is gated by ``KORA_TEST_NEO4J=1``: connects to a
  live Neo4j, runs the real sync, and asserts the Host node was MERGEd
  with the correct timezone and at least one ``RUNS_SERVICE`` edge.
"""
import argparse
import asyncio
import os
import unittest
from typing import Any, Dict
from unittest.mock import AsyncMock, MagicMock, patch

from kora.cli.brain_sync import (
    _DryRunDriver,
    _run_sync,
    handle_brain_sync,
)


def _run(coro):
    """Run a coroutine without depending on a thread-local event loop.

    `asyncio.run()` (used by handle_brain_sync) clears the policy's loop on
    exit; on Python 3.12 the deprecated `get_event_loop()` then raises.
    Spinning up a fresh loop per call keeps every test independent.
    """
    loop = asyncio.new_event_loop()
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()


_FAKE_PARSED: Dict[str, Any] = {
    "source_file": "/etc/kryonix#nixosConfigurations.inspiron",
    "host": {"name": "inspiron", "timezone": "America/Cuiaba"},
    "services": ["openssh", "tailscale", "xserver.displayManager.gdm"],
}


class TestBrainSyncCLI(unittest.TestCase):
    """Mock-based — always runs."""

    def test_dry_run_does_not_open_neo4j_session(self):
        """--dry-run must never construct/return a real Neo4j driver."""
        # Make _get_neo4j_driver explode if anything calls it under --dry-run.
        with patch(
            "kora.core.orchestrator._get_neo4j_driver",
            side_effect=AssertionError("dry-run must not touch Neo4j"),
        ), patch(
            "kora.cli.brain_sync.eval_host_config",
            new=AsyncMock(return_value=_FAKE_PARSED),
        ):
            exit_code = _run(_run_sync(host="inspiron", config_file=None, dry_run=True))

        self.assertEqual(exit_code, 0)

    def test_dry_run_records_expected_cypher_statements(self):
        """The dry-run shim must capture 1 host MERGE + N service MERGEs."""
        recorded = {}

        async def _capture(driver, parsed):
            # The actual ingest_from_parsed uses the shim; we re-run it
            # directly here to inspect the recorded calls.
            from kora.brain.infra_parser import ingest_from_parsed as real
            await real(driver, parsed)
            recorded["calls"] = list(driver.calls)

        with patch(
            "kora.cli.brain_sync.eval_host_config",
            new=AsyncMock(return_value=_FAKE_PARSED),
        ), patch(
            "kora.cli.brain_sync.ingest_from_parsed",
            side_effect=_capture,
        ):
            exit_code = _run(_run_sync(host="inspiron", config_file=None, dry_run=True))

        self.assertEqual(exit_code, 0)
        calls = recorded["calls"]
        # 1 host MERGE + 3 service MERGEs = 4 statements.
        self.assertEqual(len(calls), 4)
        self.assertIn("MERGE (h:Host", calls[0][0])
        self.assertEqual(calls[0][1]["name"], "inspiron")
        self.assertEqual(calls[0][1]["timezone"], "America/Cuiaba")
        for service_call in calls[1:]:
            self.assertIn("MERGE (s:Service", service_call[0])
            self.assertIn(":RUNS_SERVICE", service_call[0])
            self.assertEqual(service_call[1]["host_name"], "inspiron")

    def test_live_path_invokes_ingest_with_real_driver(self):
        """Without --dry-run, the handler must call ingest_from_parsed with the orchestrator driver."""
        fake_driver = MagicMock(name="neo4j-driver")

        with patch(
            "kora.cli.brain_sync.eval_host_config",
            new=AsyncMock(return_value=_FAKE_PARSED),
        ), patch(
            "kora.core.orchestrator._get_neo4j_driver",
            return_value=fake_driver,
        ), patch(
            "kora.cli.brain_sync.ingest_from_parsed",
            new=AsyncMock(return_value=_FAKE_PARSED),
        ) as mock_ingest:
            exit_code = _run(_run_sync(host="inspiron", config_file=None, dry_run=False))

        self.assertEqual(exit_code, 0)
        mock_ingest.assert_awaited_once()
        # First positional arg = driver, second = parsed dict
        called_driver, called_parsed = mock_ingest.await_args.args
        self.assertIs(called_driver, fake_driver)
        self.assertEqual(called_parsed["host"]["name"], "inspiron")

    def test_missing_config_returns_exit_2(self):
        """If eval fails AND no fallback file exists, exit 2."""
        with patch(
            "kora.cli.brain_sync.eval_host_config",
            new=AsyncMock(return_value=None),
        ), patch(
            "pathlib.Path.exists",
            return_value=False,
        ):
            exit_code = _run(_run_sync(host="nonexistent-host", config_file=None, dry_run=False))

        self.assertEqual(exit_code, 2)

    def test_neo4j_unavailable_returns_exit_3_non_fatal(self):
        """Neo4j driver returning None must yield exit 3 (warning, not crash)."""
        with patch(
            "kora.cli.brain_sync.eval_host_config",
            new=AsyncMock(return_value=_FAKE_PARSED),
        ), patch(
            "kora.core.orchestrator._get_neo4j_driver",
            return_value=None,
        ):
            exit_code = _run(_run_sync(host="inspiron", config_file=None, dry_run=False))

        self.assertEqual(exit_code, 3)

    def test_handle_brain_sync_uses_asyncio_run(self):
        """handle_brain_sync must accept an argparse Namespace and return the exit code."""
        ns = argparse.Namespace(host="inspiron", config_file=None, dry_run=True)

        with patch(
            "kora.cli.brain_sync.eval_host_config",
            new=AsyncMock(return_value=_FAKE_PARSED),
        ):
            result = handle_brain_sync(ns)

        self.assertEqual(result, 0)

    def test_dry_run_driver_session_is_async_context(self):
        """The shim must satisfy the `async with driver.session() as s` contract."""
        async def go():
            drv = _DryRunDriver()
            async with drv.session() as session:
                await session.run("MATCH (n) RETURN n", {"k": "v"})
            return drv.calls

        calls = _run(go())
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0][0], "MATCH (n) RETURN n")
        self.assertEqual(calls[0][1], {"k": "v"})


@unittest.skipUnless(
    os.environ.get("KORA_TEST_NEO4J") == "1",
    "Live Neo4j round-trip gated by KORA_TEST_NEO4J=1",
)
class TestBrainSyncLive(unittest.TestCase):
    """Live round-trip — gated by `KORA_TEST_NEO4J=1`."""

    TEST_HOST_NAME = "kora-prodsync-test"

    def setUp(self):
        from neo4j import AsyncGraphDatabase

        uri = os.environ.get("KORA_NEO4J_URI", "bolt://127.0.0.1:7687")
        user = os.environ.get("KRYONIX_NEO4J_USER", "neo4j")
        password = os.environ.get("KRYONIX_NEO4J_PASSWORD")

        auth = (user, password) if password else None
        self.driver = AsyncGraphDatabase.driver(uri, auth=auth) if auth else \
            AsyncGraphDatabase.driver(uri)

        # Always start from a clean slate.
        _run(self._cleanup())

    def tearDown(self):
        _run(self._cleanup())
        _run(self.driver.close())

    async def _cleanup(self):
        async with self.driver.session() as s:
            await s.run(
                "MATCH (h:Host {name:$n}) DETACH DELETE h",
                {"n": self.TEST_HOST_NAME},
            )

    def test_round_trip_creates_host_and_runs_service_edges(self):
        """Sync a synthetic parsed dict and verify it shows up in Neo4j."""
        from kora.brain.infra_parser import ingest_from_parsed

        parsed = {
            "source_file": "test://prodsync",
            "host": {"name": self.TEST_HOST_NAME, "timezone": "America/Cuiaba"},
            "services": ["openssh", "tailscale"],
        }

        async def go():
            await ingest_from_parsed(self.driver, parsed)
            async with self.driver.session() as s:
                # Check Host got the right timezone.
                rec = await s.run(
                    "MATCH (h:Host {name:$n}) RETURN h.timezone AS tz",
                    {"n": self.TEST_HOST_NAME},
                )
                row = await rec.single()
                tz = row["tz"] if row else None

                # Count RUNS_SERVICE edges.
                rec2 = await s.run(
                    "MATCH (h:Host {name:$n})-[:RUNS_SERVICE]->(s:Service) "
                    "RETURN count(s) AS c",
                    {"n": self.TEST_HOST_NAME},
                )
                row2 = await rec2.single()
                count = row2["c"] if row2 else 0
            return tz, count

        tz, count = _run(go())
        self.assertEqual(tz, "America/Cuiaba")
        self.assertEqual(count, 2)


if __name__ == "__main__":
    unittest.main()
