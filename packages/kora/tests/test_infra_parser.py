import asyncio
import logging
import tempfile
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock

from kora.brain.infra_parser import (
    SERVICES_ON_HOST_CYPHER,
    ingest_infrastructure,
    ingest_many,
    parse_configuration,
    services_on_host,
)


def _run(coro):
    loop = asyncio.new_event_loop()
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()


SAMPLE_NIX = """
{ config, lib, pkgs, ... }:
{
  networking.hostName = "inspiron";
  time.timeZone = "America/Cuiaba";

  # Should not be picked up (line comment)
  # services.commented.enable = true;

  /*
    Block comment — also ignored.
    services.alsocommented.enable = true;
  */

  services.openssh.enable = true;
  services.tailscale.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.printing.enable = false;   # disabled — must be skipped
  services.openssh.enable = true;     # duplicate — must dedupe
}
"""

INVALID_NIX = """
{ config, lib, pkgs, ... :
{
  networking.hostName = "broken";
  services.openssh.enable = true;
  /* unterminated block...
"""


def _mock_driver():
    mock_session = AsyncMock()
    mock_session.run = AsyncMock()
    mock_session.__aenter__ = AsyncMock(return_value=mock_session)
    mock_session.__aexit__ = AsyncMock(return_value=False)

    mock_driver = MagicMock()
    mock_driver.session = MagicMock(return_value=mock_session)
    return mock_driver, mock_session


class TestInfraParser(unittest.TestCase):

    def test_parse_configuration_success(self):
        """parse_configuration must extract host, timezone, and deduped services."""
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "configuration.nix"
            path.write_text(SAMPLE_NIX, encoding="utf-8")

            parsed = parse_configuration(path)
            self.assertIsNotNone(parsed)
            self.assertEqual(parsed["host"]["name"], "inspiron")
            self.assertEqual(parsed["host"]["timezone"], "America/Cuiaba")
            self.assertEqual(
                parsed["services"],
                ["openssh", "tailscale", "xserver.displayManager.gdm"],
            )
            # printing.enable = false must not appear
            self.assertNotIn("printing", parsed["services"])

    def test_parse_configuration_missing_file(self):
        """parse_configuration must return None when file is missing."""
        result = parse_configuration("/tmp/this/does/not/exist.nix")
        self.assertIsNone(result)

    def test_parse_configuration_invalid_syntax_returns_none(self):
        """Invalid Nix syntax must log error and return None, never raise."""
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "configuration.nix"
            path.write_text(INVALID_NIX, encoding="utf-8")

            with self.assertLogs("kora.brain.infra_parser", level="ERROR") as cm:
                result = parse_configuration(path)

            self.assertIsNone(result)
            self.assertTrue(
                any("invalid Nix syntax" in msg.lower() or "skipping" in msg.lower()
                    for msg in cm.output)
            )

    def test_parse_configuration_mkDefault_wrapper(self):
        """networking.hostName = lib.mkDefault \"x\"; must be supported."""
        content = """
        {
          networking.hostName = lib.mkDefault "ragos-prime";
          time.timeZone = lib.mkDefault "UTC";
          services.openssh.enable = true;
        }
        """
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "configuration.nix"
            path.write_text(content, encoding="utf-8")

            parsed = parse_configuration(path)
            self.assertIsNotNone(parsed)
            self.assertEqual(parsed["host"]["name"], "ragos-prime")
            self.assertEqual(parsed["host"]["timezone"], "UTC")
            self.assertEqual(parsed["services"], ["openssh"])

    def test_ingest_infrastructure_uses_merge(self):
        """ingest_infrastructure must MERGE Host and Service nodes with RUNS_SERVICE."""
        mock_driver, mock_session = _mock_driver()

        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "configuration.nix"
            path.write_text(SAMPLE_NIX, encoding="utf-8")

            result = _run(ingest_infrastructure(mock_driver, path))

        self.assertIsNotNone(result)
        self.assertEqual(result["host"]["name"], "inspiron")

        queries = [call.args[0] for call in mock_session.run.call_args_list]
        # Host MERGE
        self.assertTrue(any("MERGE (h:Host" in q for q in queries))
        # Service MERGE
        self.assertTrue(any("MERGE (s:Service" in q for q in queries))
        # RUNS_SERVICE edge
        self.assertTrue(any(":RUNS_SERVICE" in q for q in queries))

        # Verify the host parameters were passed
        host_calls = [
            call for call in mock_session.run.call_args_list
            if "MERGE (h:Host" in call.args[0]
        ]
        self.assertEqual(len(host_calls), 1)
        host_params = host_calls[0].args[1]
        self.assertEqual(host_params["name"], "inspiron")
        self.assertEqual(host_params["timezone"], "America/Cuiaba")

    def test_ingest_infrastructure_invalid_returns_none(self):
        """A malformed file must be skipped without raising or touching the driver."""
        mock_driver, mock_session = _mock_driver()

        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "configuration.nix"
            path.write_text(INVALID_NIX, encoding="utf-8")

            with self.assertLogs("kora.brain.infra_parser", level="ERROR"):
                result = _run(ingest_infrastructure(mock_driver, path))

        self.assertIsNone(result)
        mock_session.run.assert_not_called()

    def test_ingest_many_skips_invalid(self):
        """ingest_many must process valid files and skip invalid ones, returning only successes."""
        mock_driver, _ = _mock_driver()

        with tempfile.TemporaryDirectory() as tmp:
            good = Path(tmp) / "good.nix"
            good.write_text(SAMPLE_NIX, encoding="utf-8")

            bad = Path(tmp) / "bad.nix"
            bad.write_text(INVALID_NIX, encoding="utf-8")

            missing = Path(tmp) / "missing.nix"  # not written

            with self.assertLogs("kora.brain.infra_parser", level="ERROR"):
                results = _run(ingest_many(mock_driver, [good, bad, missing]))

        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["host"]["name"], "inspiron")

    def test_services_on_host_validation_query(self):
        """services_on_host must run the validation Cypher and return service names."""
        # Build an async iterator over fake records
        records = [{"name": "openssh"}, {"name": "tailscale"}]

        class _AsyncIter:
            def __init__(self, items):
                self._items = iter(items)

            def __aiter__(self):
                return self

            async def __anext__(self):
                try:
                    return next(self._items)
                except StopIteration:
                    raise StopAsyncIteration

        mock_session = AsyncMock()
        mock_session.run = AsyncMock(return_value=_AsyncIter(records))
        mock_session.__aenter__ = AsyncMock(return_value=mock_session)
        mock_session.__aexit__ = AsyncMock(return_value=False)
        mock_driver = MagicMock()
        mock_driver.session = MagicMock(return_value=mock_session)

        names = _run(services_on_host(mock_driver, "inspiron"))
        self.assertEqual(names, ["openssh", "tailscale"])

        # Verify the exact Cypher and parameter binding
        called_query, called_params = mock_session.run.call_args.args
        self.assertEqual(called_query, SERVICES_ON_HOST_CYPHER)
        self.assertIn(":RUNS_SERVICE", called_query)
        self.assertEqual(called_params, {"host_name": "inspiron"})


if __name__ == "__main__":
    logging.basicConfig(level=logging.WARNING)
    unittest.main()
