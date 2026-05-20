"""
Test Neo4j connectivity using the same configuration as the Kora service.

This test validates:
1. Socket-level reachability of the Neo4j Bolt port.
2. Driver instantiation with basic_auth.
3. A trivial Cypher query to confirm auth and DB health.

If this test fails, the problem is infra/config.
If it passes but orchestrator fails, the problem is in the orchestrator code.
"""
import os
import socket
import asyncio
import pytest
from unittest.mock import patch
from urllib.parse import urlparse


def _get_neo4j_uri() -> str:
    """Resolve the canonical Neo4j URI using the same priority as orchestrator."""
    from kora.core.config import NEO4J_URI
    return os.getenv("KRYONIX_NEO4J_URI") or NEO4J_URI


def _get_neo4j_auth() -> tuple[str, str] | None:
    """Resolve credentials using the same logic as orchestrator."""
    from kora.core.config import NEO4J_USER, NEO4J_PASSWORD
    user = os.getenv("KRYONIX_NEO4J_USER", NEO4J_USER)
    password = os.getenv("KRYONIX_NEO4J_PASSWORD", NEO4J_PASSWORD)
    if user and password:
        return (user, password)
    auth_str = os.getenv("NEO4J_AUTH", "")
    if "/" in auth_str:
        u, p = auth_str.split("/", 1)
        return (u, p)
    return None


class TestNeo4jConnectivity:
    """Live connectivity tests — skipped when Neo4j is unreachable."""

    def _check_socket(self) -> bool:
        uri = _get_neo4j_uri()
        if "://" not in uri:
            uri = "bolt://" + uri
        parsed = urlparse(uri)
        host = parsed.hostname or "localhost"
        port = parsed.port or 7687
        try:
            with socket.create_connection((host, port), timeout=2.0):
                return True
        except Exception:
            return False

    def test_socket_reachability(self):
        """Verify that the Neo4j Bolt port is reachable at the configured URI."""
        uri = _get_neo4j_uri()
        reachable = self._check_socket()
        if not reachable:
            pytest.skip(f"Neo4j not reachable at {uri} — environment issue, not code bug")
        assert reachable

    def test_driver_instantiation(self):
        """Verify that the Neo4j driver can be created with basic_auth."""
        if not self._check_socket():
            pytest.skip("Neo4j not reachable — skipping driver test")

        from neo4j import GraphDatabase, basic_auth
        uri = _get_neo4j_uri()
        auth_tuple = _get_neo4j_auth()
        if auth_tuple:
            auth = basic_auth(auth_tuple[0], auth_tuple[1])
        else:
            auth = None

        driver = GraphDatabase.driver(uri, auth=auth)
        # verify_connectivity() will raise if auth or network fail
        try:
            driver.verify_connectivity()
        finally:
            driver.close()

    def test_trivial_cypher_query(self):
        """Run RETURN 1 to confirm full auth + query path."""
        if not self._check_socket():
            pytest.skip("Neo4j not reachable — skipping query test")

        from neo4j import GraphDatabase, basic_auth
        uri = _get_neo4j_uri()
        auth_tuple = _get_neo4j_auth()
        auth = basic_auth(*auth_tuple) if auth_tuple else None

        driver = GraphDatabase.driver(uri, auth=auth)
        try:
            with driver.session() as session:
                result = session.run("RETURN 1 AS n")
                record = result.single()
                assert record is not None
                assert record["n"] == 1
        finally:
            driver.close()


class TestNeo4jFailSafe:
    """Verify that the orchestrator handles Neo4j being offline gracefully."""

    def test_driver_returns_none_when_unreachable(self):
        """_get_neo4j_driver() must return None, not raise, when Neo4j is down."""
        import kora.core.orchestrator as orch

        # Reset module-level driver state
        orch._neo4j_driver = None
        orch._neo4j_available = False
        orch._last_neo4j_check_time = 0.0

        with patch("kora.core.orchestrator.socket.create_connection", side_effect=ConnectionRefusedError):
            result = orch._get_neo4j_driver()

        assert result is None

    def test_process_message_survives_neo4j_offline(self):
        """process_message must return a valid dict even without Neo4j."""
        from kora.core.orchestrator import process_message

        def _run(coro):
            try:
                loop = asyncio.get_running_loop()
            except RuntimeError:
                loop = None
            if loop and loop.is_running():
                return asyncio.ensure_future(coro)
            try:
                return asyncio.get_event_loop().run_until_complete(coro)
            except RuntimeError:
                return asyncio.new_event_loop().run_until_complete(coro)

        with patch("kora.core.orchestrator.socket.create_connection", side_effect=ConnectionRefusedError), \
             patch("kora.core.orchestrator.ollama_adapter") as mock_ollama:

            async def _mock_chat(**kw):
                return {"answer": "Test fallback", "model": "mock"}

            mock_ollama.chat_with_turns = _mock_chat
            import kora.core.orchestrator as orch
            orch._neo4j_driver = None
            orch._neo4j_available = False
            orch._last_neo4j_check_time = 0.0

            result = _run(process_message("bom dia", session_id="neo4j-test"))

        assert isinstance(result, dict)
        assert "answer" in result
