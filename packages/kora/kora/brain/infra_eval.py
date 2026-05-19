"""
Evaluate a NixOS host's *fully imported* configuration via ``nix eval`` and
produce a parse dict compatible with :func:`kora.brain.infra_parser.ingest_from_parsed`.

The regex-based :func:`parse_configuration` only reads a single file, which
silently drops services enabled in imported modules (e.g. ``services.openssh``
declared in ``modules/nixos/common/default.nix``). This module shells out to
``nix eval`` against the flake's ``nixosConfigurations.<host>.config`` so the
resulting service list reflects what NixOS will actually activate.

If ``nix`` is not on PATH, the flake fails to evaluate, the evaluation times
out, or the JSON is malformed, this function returns ``None`` and logs the
failure. The CLI handler is expected to then fall back to the regex parser.
"""
from __future__ import annotations

import asyncio
import json
import logging
from pathlib import Path
from typing import Any, Dict, Optional

logger = logging.getLogger("kora.brain.infra_eval")

DEFAULT_FLAKE_REF = "/etc/kryonix"
DEFAULT_EVAL_TIMEOUT_S = 60

# Path to the bundled .nix helper that lives next to this module.
_HELPER_NIX = Path(__file__).with_suffix(".nix")


async def eval_host_config(
    host: str,
    flake_ref: str = DEFAULT_FLAKE_REF,
    timeout: float = DEFAULT_EVAL_TIMEOUT_S,
) -> Optional[Dict[str, Any]]:
    """
    Run ``nix eval --json -f infra_eval.nix --argstr host <host> --argstr flake <ref>``
    and return a dict shaped for ``ingest_from_parsed``::

        {
            "source_file": "<flake_ref>#nixosConfigurations.<host>",
            "host":        {"name": "<hostName>", "timezone": "<tz>" | None},
            "services":    ["openssh", "tailscale", "xserver.displayManager.gdm", ...],
        }

    Returns ``None`` on any failure (binary missing, eval error, timeout,
    malformed JSON). The failure is logged via ``logging.error`` so the
    caller can fall back to the regex parser without an explicit raise.
    """
    if not _HELPER_NIX.exists():
        logger.error("Nix helper not found at %s", _HELPER_NIX)
        return None

    # Apply the helper as a function over the fully-resolved NixOS config.
    # Using `nix eval --apply` against a flake ref (rather than `nix-instantiate -f`)
    # makes Nix copy the source to /nix/store with gitignore filtering, so
    # secrets like /etc/kryonix/kora.env (mode 600) don't need to be readable
    # by the caller.
    cmd = [
        "nix", "eval",
        "--json",
        "--impure",  # accepts a non-pinned flake ref like /etc/kryonix
        "--apply", f"import {_HELPER_NIX}",
        f"{flake_ref}#nixosConfigurations.{host}.config",
    ]
    logger.info("Evaluating host config | host=%s flake=%s", host, flake_ref)

    try:
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
    except FileNotFoundError:
        logger.error("`nix` binary not found in PATH; cannot eval host=%s", host)
        return None

    try:
        out, err = await asyncio.wait_for(proc.communicate(), timeout=timeout)
    except asyncio.TimeoutError:
        proc.kill()
        await proc.wait()
        logger.error("nix eval timed out after %ss for host=%s", timeout, host)
        return None

    if proc.returncode != 0:
        # Truncate stderr to keep logs sane on big Nix error blobs.
        snippet = err.decode("utf-8", errors="replace").strip()
        if len(snippet) > 800:
            snippet = snippet[:800] + " …(truncated)"
        logger.error("nix eval failed (rc=%d) for host=%s: %s",
                     proc.returncode, host, snippet)
        return None

    try:
        data = json.loads(out)
    except json.JSONDecodeError as exc:
        logger.error("nix eval produced invalid JSON for host=%s: %s", host, exc)
        return None

    name = data.get("name")
    if not name:
        logger.error("nix eval result missing 'name' for host=%s: %r", host, data)
        return None

    services = data.get("services") or []
    timezone = data.get("timezone")

    parsed: Dict[str, Any] = {
        "source_file": f"{flake_ref}#nixosConfigurations.{host}",
        "host":        {"name": name, "timezone": timezone},
        "services":    list(services),
    }
    logger.info(
        "Eval ok | host=%s timezone=%s services=%d",
        name, timezone, len(services),
    )
    return parsed
