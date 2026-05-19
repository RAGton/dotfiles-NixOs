"""
``kora brain sync`` — sync a NixOS host's configuration into the Neo4j graph.

Resolution order for the source config:
  1. ``--config-file PATH``         — explicit override; uses the regex parser.
  2. ``nix eval`` on the flake      — preferred; resolves imports correctly.
  3. ``/etc/kryonix/hosts/<host>/default.nix`` regex fallback (if file exists).

``--dry-run`` swaps the Neo4j driver for an in-memory shim that records every
Cypher statement (with bound parameters) without opening any TCP session.
"""
from __future__ import annotations

import argparse
import asyncio
import logging
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from ..brain.infra_eval import eval_host_config
from ..brain.infra_parser import ingest_from_parsed, parse_configuration

logger = logging.getLogger("kora.cli.brain_sync")


# ----------------------------------------------------------------------
# Dry-run shim — mimics the subset of neo4j.AsyncDriver that ingest_from_parsed
# touches: `.session(...)` returns an async context manager that exposes
# `await session.run(query, params)`. Nothing here ever opens a socket.
# ----------------------------------------------------------------------
class _DryRunResult:
    def __aiter__(self):
        return self

    async def __anext__(self):
        raise StopAsyncIteration


class _DryRunSession:
    def __init__(self, driver: "_DryRunDriver") -> None:
        self._driver = driver

    async def __aenter__(self) -> "_DryRunSession":
        return self

    async def __aexit__(self, *_exc: Any) -> bool:
        return False

    async def run(self, query: str, params: Optional[Dict[str, Any]] = None) -> _DryRunResult:
        self._driver.calls.append((query, dict(params or {})))
        logger.info(
            "[DRY-RUN] Cypher:\n%s\n[DRY-RUN] Params: %s",
            query.strip(),
            params or {},
        )
        return _DryRunResult()


class _DryRunDriver:
    """Records (query, params) pairs without executing or connecting."""

    def __init__(self) -> None:
        self.calls: List[Tuple[str, Dict[str, Any]]] = []

    def session(self, **_kwargs: Any) -> _DryRunSession:
        return _DryRunSession(self)


# ----------------------------------------------------------------------
# Config resolution
# ----------------------------------------------------------------------
async def _resolve_parsed(
    host: str,
    config_file: Optional[str],
) -> Optional[Dict[str, Any]]:
    """
    Pick the best available source for ``host``'s parsed infra dict and
    return it. Logs and returns ``None`` if no source is available.
    """
    if config_file:
        logger.info("Using explicit --config-file %s (regex parser)", config_file)
        return parse_configuration(config_file)

    parsed = await eval_host_config(host)
    if parsed is not None:
        return parsed

    fallback = Path(f"/etc/kryonix/hosts/{host}/default.nix")
    if fallback.exists():
        logger.warning(
            "nix eval failed; falling back to regex parse of %s "
            "(services in imported modules will be missed)",
            fallback,
        )
        return parse_configuration(fallback)

    logger.error(
        "No configuration source found for host=%s "
        "(nix eval failed and %s does not exist)",
        host, fallback,
    )
    return None


# ----------------------------------------------------------------------
# Core handler
# ----------------------------------------------------------------------
async def _run_sync(
    host: str,
    config_file: Optional[str],
    dry_run: bool,
) -> int:
    """
    Returns a process exit code:
        0 — success (or successful dry-run)
        2 — config source missing/invalid
        3 — Neo4j unavailable (non-fatal: caller should treat as warning)
    """
    parsed = await _resolve_parsed(host, config_file)
    if parsed is None:
        return 2

    if dry_run:
        drv = _DryRunDriver()
        await ingest_from_parsed(drv, parsed)
        print(
            f"[DRY-RUN] would issue {len(drv.calls)} Cypher statements "
            f"for host={parsed['host']['name']} "
            f"services={len(parsed['services'])} "
            f"timezone={parsed['host'].get('timezone')}"
        )
        return 0

    # Import here to avoid pulling in neo4j/orchestrator deps for --dry-run.
    from ..core.orchestrator import _get_neo4j_driver
    driver = _get_neo4j_driver()
    if driver is None:
        logger.warning(
            "Neo4j unavailable — skipping sync for host=%s (non-fatal)", host
        )
        return 3

    await ingest_from_parsed(driver, parsed)
    print(
        f"Synced host={parsed['host']['name']} "
        f"services={len(parsed['services'])} "
        f"timezone={parsed['host'].get('timezone')}"
    )
    return 0


def handle_brain_sync(args: argparse.Namespace) -> int:
    """argparse entry point used from ``kora.cli.admin``."""
    return asyncio.run(
        _run_sync(
            host=args.host,
            config_file=args.config_file,
            dry_run=args.dry_run,
        )
    )


# ----------------------------------------------------------------------
# Stand-alone entry point: `python -m kora.cli.brain_sync ...`
# ----------------------------------------------------------------------
def main(argv: Optional[List[str]] = None) -> None:
    parser = argparse.ArgumentParser(prog="kora-brain-sync")
    parser.add_argument("--host", required=True, help="Target hostname")
    parser.add_argument(
        "--config-file",
        default=None,
        help="Override path (bypasses nix eval; uses regex parser)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Log Cypher without writing to Neo4j",
    )
    args = parser.parse_args(argv)
    sys.exit(handle_brain_sync(args))


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s | %(message)s")
    main()
