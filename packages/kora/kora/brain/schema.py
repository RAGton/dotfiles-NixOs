import logging
from typing import Any

logger = logging.getLogger("kora.brain.schema")


class NodeLabels:
    NOTE = "Note"
    CHUNK = "Chunk"
    CONCEPT = "Concept"
    CONVERSATION = "Conversation"
    HOST = "Host"
    SERVICE = "Service"


class Relationships:
    MENTIONS = "MENTIONS"
    PART_OF = "PART_OF"
    EXPLAINS = "EXPLAINS"
    RUNS_ON = "RUNS_ON"
    RUNS_SERVICE = "RUNS_SERVICE"


async def init_graph(driver: Any) -> None:
    """
    Initialise unique constraints on the graph database nodes.
    Creates uniqueness constraints for Note.id, Concept.name, Host.name,
    Service.name, and Chunk.id.
    """
    constraints = [
        "CREATE CONSTRAINT note_id_unique IF NOT EXISTS FOR (n:Note) REQUIRE n.id IS UNIQUE",
        "CREATE CONSTRAINT concept_name_unique IF NOT EXISTS FOR (c:Concept) REQUIRE c.name IS UNIQUE",
        "CREATE CONSTRAINT host_name_unique IF NOT EXISTS FOR (h:Host) REQUIRE h.name IS UNIQUE",
        "CREATE CONSTRAINT service_name_unique IF NOT EXISTS FOR (s:Service) REQUIRE s.name IS UNIQUE",
        "CREATE CONSTRAINT chunk_id_unique IF NOT EXISTS FOR (ch:Chunk) REQUIRE ch.id IS UNIQUE",
    ]

    logger.info("Initializing Neo4j schema constraints...")
    try:
        async with driver.session() as session:
            for statement in constraints:
                logger.debug("Executing schema statement: %s", statement)
                await session.run(statement)
        logger.info("Neo4j schema constraints initialized successfully.")
    except Exception as exc:
        logger.error("Failed to initialize Neo4j schema constraints: %s", exc)
        raise exc
