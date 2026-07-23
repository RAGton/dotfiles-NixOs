#!/usr/bin/env python3
"""Detect cross-repository contract drift and emit a compact context pack.

This is intentionally conservative: it reports evidence and never edits the
source repositories. It does not read dependency locks, generated assets or
sensitive files.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
SENSITIVE_PARTS = {".git", "target", "dist", "node_modules", "artifacts", "static/assets"}


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def json_read(path: Path) -> dict[str, Any]:
    return json.loads(read(path))


def version_const(text: str, name: str) -> int | None:
    match = re.search(rf"(?:const|let|var)\s+{re.escape(name)}\s*=\s*(\d+)", text)
    return int(match.group(1)) if match else None


def schema_version(path: Path) -> int | None:
    try:
        data = json_read(path)
    except (OSError, ValueError):
        return None
    value = data.get("properties", {}).get("version", {}).get("const")
    return int(value) if isinstance(value, int) else None


def required_keys(path: Path) -> list[str]:
    try:
        data = json_read(path)
    except (OSError, ValueError):
        return []
    value = data.get("required", [])
    return sorted(str(item) for item in value)


def raw_payload_keys(text: str) -> list[str]:
    match = re.search(r"const rawPayload\s*=\s*\{(.*?)\n\s*\};", text, re.DOTALL)
    if not match:
        return []
    return sorted(set(re.findall(r"^\s{4}([A-Za-z_$][\w$]*)\s*:", match.group(1), re.MULTILINE)))


def has(text: str, pattern: str) -> bool:
    return re.search(pattern, text, re.MULTILINE) is not None


def capability_registry_check(kryxd: Path, catalog_text: str) -> dict[str, Any]:
    registry_path = kryxd / "schemas/capabilities.json"
    try:
        registry = json_read(registry_path)
    except (OSError, ValueError):
        return {"path": str(registry_path), "ids": [], "duplicateIds": [], "missingFromCatalog": [], "catalogOnly": []}
    registry_ids = [str(item.get("id")) for item in registry.get("capabilities", [])]
    catalog_ids = sorted(set(re.findall(r"^\\s*id: '([^']+)',", catalog_text, re.MULTILINE)))
    duplicates = sorted({item for item in registry_ids if registry_ids.count(item) > 1})
    return {
        "path": str(registry_path),
        "ids": sorted(set(registry_ids)),
        "duplicateIds": duplicates,
        "missingFromCatalog": sorted(set(catalog_ids) - set(registry_ids)),
        "catalogOnly": sorted(set(registry_ids) - set(catalog_ids)),
    }


def finding(code: str, severity: str, source: list[str], message: str, remediation: str) -> dict[str, Any]:
    return {
        "code": code,
        "severity": severity,
        "source": source,
        "message": message,
        "remediation": remediation,
    }


def contract_drift(engine: Path, kryxd: Path) -> dict[str, Any]:
    backend_schema_path = kryxd / "schemas/install-plan.schema.json"
    ui_schema_path = kryxd / "ui/src/install-plan.schema.json"
    producer_path = kryxd / "ui/src/utils/installPlan.js"
    backend_domain_path = kryxd / "crates/kryx/src/domain/config.rs"
    main_path = kryxd / "src/main.rs"
    api_path = kryxd / "src/api/mod.rs"
    feature_path = kryxd / "ui/src/data/featureCatalog.js"

    backend_schema = schema_version(backend_schema_path)
    ui_schema = schema_version(ui_schema_path)
    backend_required = required_keys(backend_schema_path)
    ui_required = required_keys(ui_schema_path)
    producer = read(producer_path)
    domain = read(backend_domain_path)
    main = read(main_path)
    api = read(api_path)
    features = read(feature_path)
    registry = capability_registry_check(kryxd, features)
    producer_version = version_const(producer, "INSTALL_PLAN_VERSION")
    payload_keys = raw_payload_keys(producer)

    findings: list[dict[str, Any]] = []
    if registry["duplicateIds"] or registry["missingFromCatalog"]:
        findings.append(finding(
            "CAPABILITY_REGISTRY_DRIFT", "high", [registry["path"], str(feature_path)],
            f"Registry duplicado ou incompleto: duplicados={registry['duplicateIds'] or 'nenhum'}, ausentes={registry['missingFromCatalog'] or 'nenhum'}.",
            "Regenerar o registry de forma determinística e revisar a projeção da UI.",
        ))
    if backend_schema != 2 or not has(domain, r"pub struct InstallPlanV2"):
        findings.append(finding(
            "BACKEND_V2_SOURCE_MISSING", "high",
            [str(backend_schema_path), str(backend_domain_path)],
            "A fonte v2 esperada não foi encontrada de forma consistente.",
            "Restaurar o vínculo entre schema, InstallPlanV2 e endpoint /api/v2.",
        ))
    if ui_schema != backend_schema:
        findings.append(finding(
            "UI_SCHEMA_VERSION_DRIFT", "high",
            [str(ui_schema_path), str(backend_schema_path)],
            f"Schema da UI declara v{ui_schema}; schema do backend declara v{backend_schema}.",
            "Fazer a UI consumir o schema v2 canônico; não relaxar o deserializador Rust.",
        ))
    if producer_version != backend_schema:
        findings.append(finding(
            "UI_PRODUCER_VERSION_DRIFT", "high",
            [str(producer_path), str(backend_schema_path)],
            f"Producer declara INSTALL_PLAN_VERSION={producer_version}, enquanto o backend exige v{backend_schema}.",
            "Unificar a constante e os testes com InstallPlanV2.",
        ))
    missing = sorted(set(backend_required) - set(payload_keys))
    extra = sorted(set(payload_keys) - set(backend_required))
    if missing or extra:
        findings.append(finding(
            "UI_PAYLOAD_SHAPE_DRIFT", "high",
            [str(producer_path), str(backend_schema_path), str(backend_domain_path)],
            f"Chaves requeridas ausentes no producer: {missing or 'nenhuma'}; chaves do envelope antigo/extras: {extra or 'nenhuma'}.",
            "Construir exatamente o envelope repository/storage/features do v2 e manter estado de UI fora do contrato.",
        ))
    if not has(main, r"nest\(\s*\"/api/v2\"\s*,\s*api::router\(\)"):
        findings.append(finding(
            "API_V2_MOUNT_MISSING", "medium", [str(main_path), str(api_path)],
            "A montagem esperada de /api/v2 não foi localizada.",
            "Confirmar o prefixo de roteamento antes de migrar o cliente.",
        ))
    unsupported = []
    for capability, pattern in {
        "storage.raid": r'"raid"',
        "storage.manual": r'"manual"',
        "storage.luks2": r'"luks2"',
    }.items():
        if has(read(kryxd / "src/services/partitioner.rs"), pattern):
            unsupported.append(capability)
    if unsupported:
        findings.append(finding(
            "CAPABILITY_BACKEND_BLOCKS", "medium", [str(kryxd / "src/services/partitioner.rs"), str(feature_path)],
            "O backend possui bloqueios explícitos para: " + ", ".join(unsupported) + ".",
            "Representar o bloqueio no registry compartilhado; não promover essas capacidades para ready.",
        ))

    return {
        "schemaVersion": SCHEMA_VERSION,
        "status": "DRIFT_DETECTED" if findings else "NO_DRIFT_DETECTED",
        "sources": {
            "engine": str(engine),
            "kryxd": str(kryxd),
            "backendSchemaVersion": backend_schema,
            "uiSchemaVersion": ui_schema,
            "uiProducerVersion": producer_version,
            "backendRequired": backend_required,
            "uiRequired": ui_required,
            "producerKeys": payload_keys,
            "capabilityRegistry": registry,
        },
        "findings": findings,
    }


def context_pack(engine: Path, kryxd: Path, drift: dict[str, Any]) -> dict[str, Any]:
    references = [
        "docs/audits/REPOSITORY_TRUTH_MATRIX.md",
        "docs/audits/LEGACY_RETIREMENT_PLAN.md",
        "docs/installer/INSTALL_PLAN.md",
        "kryxd/schemas/install-plan.schema.json",
        "kryxd/crates/kryx/src/domain/config.rs",
        "kryxd/ui/src/utils/installPlan.js",
        "kryxd/ui/src/data/featureCatalog.js",
        "kryxd/src/api/mod.rs",
        "kryxd/src/main.rs",
    ]
    return {
        "schemaVersion": SCHEMA_VERSION,
        "purpose": "compact repository context for review and dry-run agents",
        "policy": {
            "readOnly": True,
            "secrets": "never included",
            "generatedAssets": "excluded",
            "knowledgePublication": "not performed",
        },
        "repositories": {
            "engine": str(engine),
            "kryxd": str(kryxd),
        },
        "truth": {
            "installerContract": "kryxd/crates/kryx/src/domain/config.rs::InstallPlanV2",
            "installerSchema": "kryxd/schemas/install-plan.schema.json",
            "installerApi": "/api/v2",
            "operationalApi": "/api/v1",
            "capabilityProjection": "kryxd/ui/src/data/featureCatalog.js",
        },
        "references": references,
        "driftStatus": drift["status"],
        "blockingFindings": [
            {"code": item["code"], "severity": item["severity"], "message": item["message"]}
            for item in drift["findings"]
            if item["severity"] == "high"
        ],
        "nextSafeActions": [
            "unificar UI e backend no InstallPlanV2",
            "introduzir registry de capabilities versionado",
            "gerar projeções UI/backend e comparar drift no CI",
            "manter API operacional v1 até evidência de zero consumidores",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--kryxd", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--fail-on-drift", action="store_true")
    args = parser.parse_args()
    drift = contract_drift(args.engine, args.kryxd)
    pack = context_pack(args.engine, args.kryxd, drift)
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "contract-drift.json").write_text(json.dumps(drift, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (args.output / "context-pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": drift["status"], "findings": len(drift["findings"]), "output": str(args.output)}, ensure_ascii=False))
    if args.fail_on_drift and drift["findings"]:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
