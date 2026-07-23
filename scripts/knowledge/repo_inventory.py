#!/usr/bin/env python3
"""Deterministic repository intelligence inventory for Kryonix.

The scanner intentionally uses only the filesystem, Git metadata and regular
expressions. It does not invoke an LLM and never reads sensitive files.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Iterable

SCHEMA_VERSION = 1
DEFAULT_EXCLUDES = {
    ".git",
    ".direnv",
    ".cache",
    "node_modules",
    "target",
    "dist",
    "result",
    "vendor",
    "coverage",
    "playwright-report",
    "test-results",
    "__pycache__",
    "artifacts",
}
LOCK_NAMES = {"Cargo.lock", "package-lock.json", "pnpm-lock.yaml", "yarn.lock", "flake.lock"}
SENSITIVE_NAMES = {
    ".env",
    "brain.env",
    "neo4j.env",
    "auth.json",
    "credentials.json",
    "secrets.json",
}
SENSITIVE_SUFFIXES = {".secret", ".key", ".pem", ".p12", ".pfx", ".crt"}
SENSITIVE_PREFIXES = ("id_ed25519", "id_rsa", "id_ecdsa", "id_dsa")
TEXT_SUFFIXES = {
    ".rs", ".nix", ".py", ".sh", ".bash", ".js", ".jsx", ".ts", ".tsx",
    ".json", ".toml", ".yaml", ".yml", ".md", ".txt", ".html", ".css",
    ".lock",
}
ROUTE_RE = re.compile(r"(?:route|nest|merge)\s*\(\s*[\"'](/[^\"']+)")
METHOD_ROUTE_RE = re.compile(r"\b(get|post|put|patch|delete|head)\s*\(\s*[\"'](/[^\"']+)")
FETCH_RE = re.compile(r"(?:fetch|axios\.(?:get|post|put|patch|delete))\s*\(\s*[`\"']([^`\"']+)")
PATH_LITERAL_RE = re.compile(r"[`\"'](/api/(?:v1|v2)[^`\"']*)[`\"']")
TODO_RE = re.compile(r"\b(TODO|FIXME|XXX|HACK)\b", re.IGNORECASE)
LEGACY_RE = re.compile(r"\b(legacy|deprecated|obsolete|compat|v1|placeholder|stub)\b", re.IGNORECASE)


def run_git(repo: Path, args: list[str]) -> str:
    try:
        result = subprocess.run(
            ["git", "-C", str(repo), *args],
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
    except OSError:
        return ""
    return result.stdout.strip() if result.returncode == 0 else ""


def classify(path: Path) -> str:
    name = path.name
    lower = name.lower()
    if name in SENSITIVE_NAMES or lower.startswith(".env") or any(name.startswith(p) for p in SENSITIVE_PREFIXES):
        return "sensitive"
    if path.suffix.lower() in SENSITIVE_SUFFIXES or ".secret" in lower:
        return "sensitive"
    if name in LOCK_NAMES:
        return "dependency-lock"
    return "text" if path.suffix.lower() in TEXT_SUFFIXES or name in {"README", "LICENSE", "AGENTS.md"} else "binary-or-unknown"


def excluded(path: Path, repo: Path) -> bool:
    rel_path = path.relative_to(repo)
    parts = rel_path.parts
    return (
        any(part in DEFAULT_EXCLUDES for part in parts)
        or path.name in LOCK_NAMES
        or parts[:3] == ("ui", "static", "assets")
    )


def iter_files(repo: Path) -> Iterable[Path]:
    for path in sorted(repo.rglob("*")):
        if not path.is_file() or excluded(path, repo):
            continue
        yield path


def safe_read(path: Path, max_bytes: int = 1_500_000) -> str | None:
    if classify(path) != "text":
        return None
    try:
        if path.stat().st_size > max_bytes:
            return None
        return path.read_text(encoding="utf-8", errors="replace")
    except (OSError, UnicodeError):
        return None


def rel(repo: Path, path: Path) -> str:
    return path.relative_to(repo).as_posix()


def line_hits(text: str, pattern: re.Pattern[str]) -> list[dict[str, object]]:
    hits: list[dict[str, object]] = []
    for line_no, line in enumerate(text.splitlines(), 1):
        if pattern.search(line):
            hits.append({"line": line_no, "text": line.strip()[:240]})
    return hits


def git_metadata(repo: Path) -> dict[str, object]:
    return {
        "root": run_git(repo, ["rev-parse", "--show-toplevel"]),
        "branch": run_git(repo, ["branch", "--show-current"]),
        "commit": run_git(repo, ["rev-parse", "HEAD"]),
        "status": run_git(repo, ["status", "--short"]),
        "remote": run_git(repo, ["remote", "get-url", "origin"]),
    }


def base_files(repo: Path) -> tuple[list[dict[str, object]], dict[str, str]]:
    records: list[dict[str, object]] = []
    texts: dict[str, str] = {}
    for path in iter_files(repo):
        relative = rel(repo, path)
        kind = classify(path)
        record: dict[str, object] = {
            "path": "<redacted>" if kind == "sensitive" else relative,
            "classification": kind,
            "contentRead": False,
        }
        try:
            record["bytes"] = path.stat().st_size
        except OSError:
            record["bytes"] = None
        if kind == "sensitive":
            records.append(record)
            continue
        text = safe_read(path)
        if text is not None:
            texts[relative] = text
            record["contentRead"] = True
            record["sha256"] = hashlib.sha256(text.encode("utf-8")).hexdigest()
        records.append(record)
    return records, texts


def scan_crates_packages(repo: Path, texts: dict[str, str]) -> list[dict[str, object]]:
    items: list[dict[str, object]] = []
    for path, text in sorted(texts.items()):
        if path.endswith("Cargo.toml"):
            name = re.search(r"(?m)^name\s*=\s*[\"']([^\"']+)", text)
            version = re.search(r"(?m)^version\s*=\s*[\"']([^\"']+)", text)
            items.append({"kind": "rust-crate", "path": path, "name": name.group(1) if name else None, "version": version.group(1) if version else None})
        elif path == "flake.nix":
            attrs = sorted(set(re.findall(r"(?m)^\s*([A-Za-z0-9_.-]+)\s*=\s*(?:pkgs\.)?(?:callPackage|self\.packages|mk[A-Za-z]+)", text)))
            items.append({"kind": "flake", "path": path, "declaredAttributes": attrs})
        elif path.startswith("packages/") and path.endswith((".nix", ".py", ".rs")):
            items.append({"kind": "package-source", "path": path})
    return items


def scan_nix_modules(texts: dict[str, str]) -> list[dict[str, object]]:
    result: list[dict[str, object]] = []
    for path in sorted(texts):
        if not path.endswith(".nix"):
            continue
        if not (path.startswith(("modules/", "features/", "profiles/", "hosts/", "flake/")) or "/modules/" in path):
            continue
        text = texts[path]
        options = sorted(set(re.findall(r"(?:mkEnableOption|mkOption)[^\n]*|(?:kryonix|services)\.[A-Za-z0-9_.-]+", text)))[:40]
        result.append({"path": path, "layer": path.split("/", 1)[0], "optionsOrSignals": options})
    return result


def scan_api(repo: Path, texts: dict[str, str]) -> list[dict[str, object]]:
    routes: list[dict[str, object]] = []
    for path, text in sorted(texts.items()):
        if not (path.endswith(".rs") and (path.startswith("src/") or "/src/" in path)):
            continue
        for line_no, line in enumerate(text.splitlines(), 1):
            for method, route in METHOD_ROUTE_RE.findall(line):
                routes.append({"repoPath": path, "line": line_no, "method": method.upper(), "path": route, "middlewareSignals": re.findall(r"(?:layer|auth|guard|permission|role|token)[A-Za-z0-9_:.()-]*", line, re.I)[:8]})
            for route in ROUTE_RE.findall(line):
                if not any(r["repoPath"] == path and r["line"] == line_no and r["path"] == route for r in routes):
                    routes.append({"repoPath": path, "line": line_no, "method": None, "path": route, "middlewareSignals": re.findall(r"(?:layer|auth|guard|permission|role|token)[A-Za-z0-9_:.()-]*", line, re.I)[:8]})
    dedup: dict[tuple[object, ...], dict[str, object]] = {}
    for item in routes:
        dedup[(item["repoPath"], item["line"], item["method"], item["path"])] = item
    return list(sorted(dedup.values(), key=lambda x: (str(x["path"]), str(x["method"]), str(x["repoPath"]), int(str(x["line"])))))


def scan_ui(texts: dict[str, str]) -> list[dict[str, object]]:
    routes: list[dict[str, object]] = []
    for path, text in sorted(texts.items()):
        if not (path.startswith("ui/") and path.endswith((".js", ".jsx", ".ts", ".tsx"))):
            continue
        for line_no, line in enumerate(text.splitlines(), 1):
            for route in FETCH_RE.findall(line) + PATH_LITERAL_RE.findall(line):
                if route.startswith("/api/"):
                    routes.append({"path": route, "sourcePath": path, "line": line_no, "text": line.strip()[:240]})
    dedup: dict[tuple[str, str, int], dict[str, object]] = {}
    for item in routes:
        key = (str(item["path"]), str(item["sourcePath"]), int(str(item["line"])))
        dedup[key] = item
    return list(sorted(dedup.values(), key=lambda x: (str(x["path"]), str(x["sourcePath"]), int(str(x["line"])))))


def scan_schemas(texts: dict[str, str]) -> list[dict[str, object]]:
    result: list[dict[str, object]] = []
    for path, text in sorted(texts.items()):
        if not (path.endswith(".json") and ("schema" in path.lower() or path.startswith("schemas/"))):
            continue
        try:
            value = json.loads(text)
            props = sorted(value.get("properties", {}).keys()) if isinstance(value, dict) else []
            result.append({"path": path, "title": value.get("title") if isinstance(value, dict) else None, "type": value.get("type") if isinstance(value, dict) else None, "properties": props})
        except json.JSONDecodeError:
            result.append({"path": path, "parseError": True})
    return result


def scan_tests(texts: dict[str, str]) -> list[dict[str, object]]:
    result: list[dict[str, object]] = []
    for path, text in sorted(texts.items()):
        if "/test" in path or path.startswith("tests/") or path.endswith(("_test.rs", ".test.js", ".test.jsx", ".spec.js", ".spec.jsx")):
            result.append({"path": path, "rustTests": len(re.findall(r"#\s*\[\s*test\s*\]", text)), "jsTests": len(re.findall(r"\b(?:test|it|describe)\s*\(", text)), "todoHits": len(TODO_RE.findall(text))})
    return result


def scan_capabilities(texts: dict[str, str]) -> list[dict[str, object]]:
    result: list[dict[str, object]] = []
    for path, text in sorted(texts.items()):
        if not (path.endswith((".nix", ".js", ".jsx", ".json", ".rs")) and ("feature" in path.lower() or "capabilit" in path.lower() or path.endswith("featureCatalog.js"))):
            continue
        signals = sorted(set(re.findall(r"(?:virtualization|development|gaming|desktop|ai|brain|incus|storage|cluster|ceph|terminal|logs|systemd|installer|management|kcp)(?:\.[a-z0-9_-]+)*", text, re.I)))
        if signals:
            result.append({"path": path, "signals": signals[:100]})
    return result


def docs_for_repo(texts: dict[str, str]) -> list[str]:
    return [path for path in sorted(texts) if path.endswith((".md", ".mdx")) and not path.startswith("docs/archive/")]


def scan_doc_coverage(texts: dict[str, str], api: list[dict[str, object]], ui: list[dict[str, object]]) -> dict[str, object]:
    docs = docs_for_repo(texts)
    doc_blob = "\n".join(texts[p] for p in docs).lower()
    api_items = []
    for item in api:
        route = str(item["path"])
        api_items.append({**item, "documented": route.lower() in doc_blob or route.replace("/api/v2", "") in doc_blob})
    ui_items = []
    for item in ui:
        route = str(item["path"])
        ui_items.append({**item, "documented": route.lower() in doc_blob or route.replace("/api/v2", "") in doc_blob})
    return {"documentationFiles": docs, "apiCoverage": api_items, "uiCoverage": ui_items, "undocumentedApiCount": sum(not bool(x["documented"]) for x in api_items), "undocumentedUiCount": sum(not bool(x["documented"]) for x in ui_items)}


def scan_legacy(texts: dict[str, str]) -> dict[str, object]:
    occurrences: list[dict[str, object]] = []
    counters: Counter[str] = Counter()
    for path, text in sorted(texts.items()):
        for line_no, line in enumerate(text.splitlines(), 1):
            tokens = TODO_RE.findall(line) + LEGACY_RE.findall(line)
            if "InstallPlan" in line:
                tokens.append("InstallPlan")
            if "disk.mode" in line:
                tokens.append("disk.mode")
            if "hashedPassword" in line:
                tokens.append("hashedPassword")
            if tokens:
                unique = sorted(set(str(t).lower() for t in tokens))
                for token in unique:
                    counters[token] += 1
                occurrences.append({"path": path, "line": line_no, "signals": unique, "text": line.strip()[:240]})
    return {"counts": dict(sorted(counters.items())), "occurrences": occurrences}


def architecture(repo: Path, texts: dict[str, str]) -> dict[str, object]:
    top = sorted({path.split("/", 1)[0] for path in texts})
    known = {
        "shared": ["domain", "services", "errors", "capabilities"],
        "installer": ["install", "plans", "secrets", "disks", "disko", "target tree", "liveinstaller"],
        "management": ["identity", "system", "logs", "terminal", "installedhost"],
        "datacenter": ["cluster", "incus", "virt", "storage", "ceph", "fleet"],
    }
    return {"topLevelDirectories": top, "boundedContextSignals": {k: sorted({s for s in v if any(s.lower() in path.lower() or s.lower() in text.lower() for path, text in texts.items())}) for k, v in known.items()}}


def scan_repo(name: str, repo: Path) -> dict[str, object]:
    records, texts = base_files(repo)
    api = scan_api(repo, texts)
    ui = scan_ui(texts)
    return {
        "name": name,
        "path": str(repo),
        "git": git_metadata(repo),
        "files": records,
        "fileCount": len(records),
        "textFileCount": sum(1 for x in records if x["classification"] == "text"),
        "sensitiveFileCount": sum(1 for x in records if x["classification"] == "sensitive"),
        "cratesAndPackages": scan_crates_packages(repo, texts),
        "nixModules": scan_nix_modules(texts),
        "apiContracts": scan_schemas(texts),
        "apiRoutes": api,
        "uiRoutes": ui,
        "capabilities": scan_capabilities(texts),
        "tests": scan_tests(texts),
        "documentationCoverage": scan_doc_coverage(texts, api, ui),
        "legacyMap": scan_legacy(texts),
        "architectureMap": architecture(repo, texts),
    }


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", action="append", required=True, help="name=path; can be repeated")
    parser.add_argument("--output", default="artifacts/repository-intelligence")
    parser.add_argument("--check", action="store_true", help="run a second pass and require deterministic output")
    args = parser.parse_args()
    repos: list[tuple[str, Path]] = []
    for item in args.repo:
        if "=" not in item:
            parser.error("--repo must be name=path")
        name, raw = item.split("=", 1)
        path = Path(raw).expanduser().resolve()
        if not path.is_dir():
            parser.error(f"repository does not exist: {path}")
        repos.append((name, path))
    repos.sort(key=lambda x: x[0])
    first = {"schemaVersion": SCHEMA_VERSION, "repositories": [scan_repo(name, path) for name, path in repos]}
    if args.check:
        second = {"schemaVersion": SCHEMA_VERSION, "repositories": [scan_repo(name, path) for name, path in repos]}
        if first != second:
            print("inventory is not deterministic", file=sys.stderr)
            return 2
    output = Path(args.output)
    write_json(output / "repo-inventory.json", first)
    per_repo = {r["name"]: r for r in first["repositories"]}
    write_json(output / "crates-and-packages.json", {"schemaVersion": SCHEMA_VERSION, "repositories": {k: v["cratesAndPackages"] for k, v in sorted(per_repo.items())}})
    write_json(output / "nix-modules.json", {"schemaVersion": SCHEMA_VERSION, "repositories": {k: v["nixModules"] for k, v in sorted(per_repo.items())}})
    write_json(output / "api-contracts.json", {"schemaVersion": SCHEMA_VERSION, "repositories": {k: {"schemas": v["apiContracts"], "routes": v["apiRoutes"]} for k, v in sorted(per_repo.items())}})
    write_json(output / "ui-routes.json", {"schemaVersion": SCHEMA_VERSION, "repositories": {k: v["uiRoutes"] for k, v in sorted(per_repo.items())}})
    write_json(output / "capabilities.json", {"schemaVersion": SCHEMA_VERSION, "repositories": {k: v["capabilities"] for k, v in sorted(per_repo.items())}})
    write_json(output / "tests-inventory.json", {"schemaVersion": SCHEMA_VERSION, "repositories": {k: v["tests"] for k, v in sorted(per_repo.items())}})
    write_json(output / "documentation-coverage.json", {"schemaVersion": SCHEMA_VERSION, "repositories": {k: v["documentationCoverage"] for k, v in sorted(per_repo.items())}})
    write_json(output / "legacy-map.json", {"schemaVersion": SCHEMA_VERSION, "repositories": {k: v["legacyMap"] for k, v in sorted(per_repo.items())}})
    write_json(output / "architecture-map.json", {"schemaVersion": SCHEMA_VERSION, "repositories": {k: v["architectureMap"] for k, v in sorted(per_repo.items())}})
    print(json.dumps({"output": str(output), "repositories": [name for name, _ in repos], "files": {name: per_repo[name]["fileCount"] for name, _ in repos}, "sensitiveFiles": {name: per_repo[name]["sensitiveFileCount"] for name, _ in repos}}, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
