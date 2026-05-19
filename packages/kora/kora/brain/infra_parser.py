"""
Parse NixOS ``configuration.nix`` files and ingest the resulting
infrastructure topology (Hosts + Services) into the Neo4j graph.

Extraction strategy (regex-based, no Nix evaluator needed):
  - ``networking.hostName = "<name>";``        -> Host.name
  - ``time.timeZone       = "<tz>";``          -> Host.timezone
  - ``services.<path>.enable = true;``         -> Service.name = "<path>"

The parser is intentionally tolerant: any single file with invalid syntax
is logged via ``logging.error`` and skipped — it must never break the
overall ingestion process (golden rule).
"""
from __future__ import annotations

import logging
import re
from pathlib import Path
from typing import Any, Dict, List, Optional

logger = logging.getLogger("kora.brain.infra_parser")


_RE_HOSTNAME = re.compile(
    r"""networking\.hostName\s*=\s*           # key
        (?:lib\.mkDefault\s*)?                # optional mkDefault wrapper
        "([^"\n]+)"                           # the quoted value
        \s*;""",
    re.VERBOSE,
)

_RE_TIMEZONE = re.compile(
    r"""time\.timeZone\s*=\s*
        (?:lib\.mkDefault\s*)?
        "([^"\n]+)"
        \s*;""",
    re.VERBOSE,
)

# Captures the dotted path between "services." and ".enable = true;"
# Allows alphanumerics, underscores, hyphens, and dots inside the path
# (e.g. services.xserver.displayManager.gdm.enable = true;).
_RE_SERVICE_ENABLE = re.compile(
    r"""services\.
        ([A-Za-z0-9_][\w\-.]*?)               # service dotted path (non-greedy)
        \.enable\s*=\s*true\s*;""",
    re.VERBOSE,
)

# Strip line comments (# ...) and block comments (/* ... */) before parsing
# so we don't pick up commented-out service enables.
_RE_LINE_COMMENT = re.compile(r"#.*$", re.MULTILINE)
_RE_BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.DOTALL)


def _strip_comments(text: str) -> str:
    text = _RE_BLOCK_COMMENT.sub("", text)
    text = _RE_LINE_COMMENT.sub("", text)
    return text


def _validate_braces(text: str) -> bool:
    """
    Cheap structural sanity check: balanced braces/brackets/parens.
    Nix is whitespace-tolerant but unbalanced delimiters always mean
    a malformed file. Quoted strings are ignored to avoid false positives.
    """
    pairs = {")": "(", "]": "[", "}": "{"}
    openers = set(pairs.values())
    closers = set(pairs.keys())

    stack: List[str] = []
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        # Skip over double-quoted strings (Nix also supports '' ... '' but
        # the rough check is fine for invalidity detection).
        if ch == '"':
            i += 1
            while i < n and text[i] != '"':
                if text[i] == "\\" and i + 1 < n:
                    i += 2
                    continue
                i += 1
            i += 1
            continue
        if ch in openers:
            stack.append(ch)
        elif ch in closers:
            if not stack or stack[-1] != pairs[ch]:
                return False
            stack.pop()
        i += 1

    return not stack


def parse_configuration(file_path: str | Path) -> Optional[Dict[str, Any]]:
    """
    Parse a single ``configuration.nix`` file and return a dict::

        {
            "source_file": "/absolute/path/configuration.nix",
            "host":     {"name": "inspiron", "timezone": "America/Cuiaba"},
            "services": ["openssh", "tailscale", ...],
        }

    Returns ``None`` if the file is missing or its syntax is invalid —
    the failure is logged via ``logging.error`` so the caller can keep
    iterating over other files.
    """
    path = Path(file_path)
    if not path.exists():
        logger.error("Configuration file not found: %s", path)
        return None

    try:
        raw = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        logger.error("Failed to read %s: %s", path, exc)
        return None

    if not _validate_braces(raw):
        logger.error(
            "Skipping %s: invalid Nix syntax (unbalanced braces/brackets/parens).",
            path,
        )
        return None

    cleaned = _strip_comments(raw)

    hostname_match = _RE_HOSTNAME.search(cleaned)
    host_name = hostname_match.group(1) if hostname_match else path.parent.name

    timezone_match = _RE_TIMEZONE.search(cleaned)
    timezone = timezone_match.group(1) if timezone_match else None

    # Preserve first-occurrence order and deduplicate.
    seen: set[str] = set()
    services: List[str] = []
    for m in _RE_SERVICE_ENABLE.finditer(cleaned):
        name = m.group(1)
        if name not in seen:
            seen.add(name)
            services.append(name)

    return {
        "source_file": str(path.resolve()),
        "host": {"name": host_name, "timezone": timezone},
        "services": services,
    }


# Cypher templates shared between the regex- and nix-eval-driven ingest paths.
HOST_MERGE_CYPHER = """\
MERGE (h:Host {name: $name})
SET h.timezone    = $timezone,
    h.source_file = $source_file
RETURN h
"""

SERVICE_MERGE_CYPHER = """\
MERGE (s:Service {name: $service_name})
WITH s
MATCH (h:Host {name: $host_name})
MERGE (h)-[:RUNS_SERVICE]->(s)
"""


async def ingest_from_parsed(
    driver: Any,
    parsed: Dict[str, Any],
) -> Dict[str, Any]:
    """
    MERGE the Host + Service nodes (and ``RUNS_SERVICE`` edges) described
    by an already-parsed dict.

    ``parsed`` must follow the shape returned by :func:`parse_configuration`
    or by ``kora.brain.infra_eval.eval_host_config``::

        {
            "source_file": str,
            "host":     {"name": str, "timezone": Optional[str]},
            "services": List[str],
        }

    Idempotent: every write uses ``MERGE``. The driver may be any object
    whose ``session(...)`` returns an async-context-manager exposing
    ``async run(query, params)`` — including the dry-run shim in
    ``kora.cli.brain_sync``.
    """
    host = parsed["host"]
    services = parsed["services"]

    logger.info(
        "Ingesting infrastructure | host=%s timezone=%s services=%d source=%s",
        host["name"],
        host.get("timezone"),
        len(services),
        parsed["source_file"],
    )

    async with driver.session() as session:
        await session.run(
            HOST_MERGE_CYPHER,
            {
                "name":         host["name"],
                "timezone":     host.get("timezone"),
                "source_file":  parsed["source_file"],
            },
        )
        for service_name in services:
            await session.run(
                SERVICE_MERGE_CYPHER,
                {"service_name": service_name, "host_name": host["name"]},
            )

    return parsed


async def ingest_infrastructure(
    driver: Any,
    file_path: str | Path,
) -> Optional[Dict[str, Any]]:
    """
    Parse a ``configuration.nix`` and MERGE the resulting Host + Service
    nodes (and ``(:Host)-[:RUNS_SERVICE]->(:Service)`` edges) into Neo4j.

    Idempotent: every write uses ``MERGE``, so re-running the ingestion is
    safe and will not produce duplicates.

    Returns the parse result on success, or ``None`` if the file was skipped
    (missing / invalid). The function never raises on malformed input.
    """
    parsed = parse_configuration(file_path)
    if parsed is None:
        return None
    return await ingest_from_parsed(driver, parsed)


async def ingest_many(
    driver: Any,
    file_paths: List[str | Path],
) -> List[Dict[str, Any]]:
    """
    Ingest a batch of configuration files. Any file that fails to parse is
    logged and skipped — the rest still go through. Returns the list of
    successful parse results.
    """
    results: List[Dict[str, Any]] = []
    for fp in file_paths:
        try:
            res = await ingest_infrastructure(driver, fp)
        except Exception as exc:  # last-resort safety net
            logger.error("Unexpected failure ingesting %s: %s", fp, exc)
            continue
        if res is not None:
            results.append(res)
    return results


# ----------------------------------------------------------------------
# Validation Cypher (use after ingest_infrastructure has populated the graph)
# ----------------------------------------------------------------------
SERVICES_ON_HOST_CYPHER = """\
MATCH (h:Host {name: $host_name})-[:RUNS_SERVICE]->(s:Service)
RETURN s.name AS name
ORDER BY s.name
"""


async def services_on_host(driver: Any, host_name: str) -> List[str]:
    """
    Return the names of all services declared as running on ``host_name``.
    Mirrors the validation query in the spec:

        MATCH (h:Host {name: 'inspiron'})-[:RUNS_SERVICE]->(s:Service)
        RETURN s.name
    """
    async with driver.session() as session:
        records = await session.run(
            SERVICES_ON_HOST_CYPHER, {"host_name": host_name}
        )
        names: List[str] = []
        async for record in records:
            names.append(record["name"])
        return names
