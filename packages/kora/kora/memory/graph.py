"""
Neo4j-backed GraphRAG provider for Kora's long-term memory layer.

Retrieves entity/relationship context from the knowledge graph using
parameterized Cypher queries (never string concatenation — no injection risk).
"""
from __future__ import annotations

import logging
from typing import Any

logger = logging.getLogger("kora.memory.graph")

# Cypher executed by retrieve_context.
# All user-supplied values are bound via $parameters — zero string concatenation.
# coalesce() guards every property access so nodes with non-standard schemas
# (missing id / entity_type / description) are still returned gracefully.
_CYPHER_RETRIEVE = """\
MATCH (n)
WHERE  toLower(coalesce(n.description, n.content, n.text, "")) CONTAINS toLower($query)
   OR  toLower(coalesce(n.id,          n.name,    ""))          CONTAINS toLower($query)
   OR  toLower(coalesce(n.name,        n.title,   ""))          CONTAINS toLower($query)
WITH n
OPTIONAL MATCH (n)-[r]-(neighbor)
WITH n,
     collect(DISTINCT {
         relation:      type(r),
         neighbor_id:   coalesce(neighbor.id,   neighbor.name,  elementId(neighbor)),
         neighbor_desc: coalesce(neighbor.description, neighbor.content, neighbor.text, "")
     })[0..5] AS connections
RETURN
    coalesce(n.id,          n.name,  elementId(n))          AS id,
    coalesce(n.entity_type, n.type,  labels(n)[0], "node")  AS entity_type,
    coalesce(n.description, n.content, n.text, "")          AS description,
    connections
ORDER BY size(coalesce(n.description, n.content, n.text, "")) DESC
LIMIT $top_k
"""

# Schema inspection queries — used by the audit/schema endpoint.
_CYPHER_SCHEMA_NODES = """\
MATCH (n)
WITH DISTINCT labels(n) AS node_labels, keys(n) AS node_props
RETURN node_labels, node_props
ORDER BY node_labels
LIMIT 100
"""

_CYPHER_SCHEMA_RELS = """\
MATCH ()-[r]-()
RETURN DISTINCT type(r) AS rel_type, keys(r) AS rel_props
ORDER BY rel_type
LIMIT 50
"""


class Neo4jGraphProvider:
    """
    Lightweight wrapper around a Neo4j AsyncDriver that retrieves
    graph context for a natural-language query.

    Parameters
    ----------
    driver:
        An ``neo4j.AsyncDriver`` (or sync ``Driver``) instance.
        The caller owns the driver lifecycle (open/close).
    database:
        Target Neo4j database name (default: "neo4j").
    """

    def __init__(self, driver: Any, database: str = "neo4j") -> None:
        self._driver = driver
        self._database = database

    async def retrieve_context(
        self,
        query: str,
        top_k: int = 3,
    ) -> list[dict[str, Any]]:
        """
        Return up to *top_k* graph nodes semantically related to *query*.

        Each item in the returned list contains:
          - ``id``          – node identifier
          - ``entity_type`` – ontology type (e.g. "service", "host", "concept")
          - ``description`` – free-text description stored on the node
          - ``connections`` – list of {relation, neighbor_id, neighbor_desc}

        The Cypher query is fully parameterised; no user input is interpolated
        into the query string.
        """
        params = {"query": query.strip(), "top_k": top_k}

        logger.debug(
            "GraphRAG retrieve | query=%r top_k=%d cypher=%r",
            query,
            top_k,
            _CYPHER_RETRIEVE.strip()[:120],
        )

        results: list[dict[str, Any]] = []
        try:
            async with self._driver.session(database=self._database) as session:
                records = await session.run(_CYPHER_RETRIEVE, params)
                async for record in records:
                    results.append({
                        "id":          record["id"] or "",
                        "entity_type": record["entity_type"] or "node",
                        "description": record["description"] or "",
                        "connections": record["connections"] or [],
                    })
        except Exception as exc:
            logger.error("GraphRAG query failed: %s", exc)
            return []

        logger.debug(
            "GraphRAG retrieve | nodes_found=%d query=%r",
            len(results),
            query,
        )
        return results

    async def get_schema(self) -> dict[str, Any]:
        """Return a snapshot of the actual Neo4j schema (node labels + props, rel types)."""
        nodes: list[dict[str, Any]] = []
        rels: list[dict[str, Any]] = []
        try:
            async with self._driver.session(database=self._database) as session:
                result = await session.run(_CYPHER_SCHEMA_NODES)
                async for r in result:
                    nodes.append({
                        "labels": list(r["node_labels"] or []),
                        "properties": sorted(r["node_props"] or []),
                    })
                result = await session.run(_CYPHER_SCHEMA_RELS)
                async for r in result:
                    rels.append({
                        "type": r["rel_type"],
                        "properties": sorted(r["rel_props"] or []),
                    })
        except Exception as exc:
            logger.error("Schema inspection failed: %s", exc)
            return {"error": str(exc), "nodes": [], "relationships": []}
        return {"nodes": nodes, "relationships": rels}

    @staticmethod
    def format_for_prompt(nodes: list[dict[str, Any]]) -> str:
        """
        Serialise retrieved graph nodes as a compact JSON block
        ready to be injected into a system prompt.
        """
        import json

        if not nodes:
            return ""

        clean = [
            {
                "id":          n.get("id", ""),
                "type":        n.get("entity_type", ""),
                "description": n.get("description", ""),
                "connections": n.get("connections", []),
            }
            for n in nodes
        ]
        return json.dumps(clean, ensure_ascii=False, indent=2)
