import logging
import re
from pathlib import Path
from typing import Any, Dict, List

logger = logging.getLogger("kora.brain.ingestor")


def split_text(text: str, chunk_size: int = 1000, overlap: int = 200) -> List[str]:
    """
    Split the input text into chunks of a fixed character length with a specified overlap.
    """
    if not text:
        return []
    if chunk_size <= 0:
        raise ValueError("chunk_size must be greater than 0")
    if overlap < 0:
        raise ValueError("overlap must be non-negative")
    if overlap >= chunk_size:
        raise ValueError("overlap must be less than chunk_size")

    chunks = []
    start = 0
    text_len = len(text)

    while start < text_len:
        end = start + chunk_size
        chunks.append(text[start:end])
        if end >= text_len:
            break
        start += chunk_size - overlap

    return chunks


def extract_concepts(text: str) -> List[str]:
    """
    Extract unique concepts from Obsidian-style wiki links [[ConceptName]],
    excluding aliases or section targets.
    """
    # Pattern to match [[PageName#Section|Alias]] and extract PageName
    pattern = r"\[\[([^\]#|]+)(?:#[^\]|]*)?(?:\|[^\]]*)?\]\]"
    matches = re.findall(pattern, text)
    # Clean whitespace and return unique values preserving order
    seen = set()
    unique_concepts = []
    for match in matches:
        cleaned = match.strip()
        if cleaned and cleaned not in seen:
            seen.add(cleaned)
            unique_concepts.append(cleaned)
    return unique_concepts


async def ingest_markdown(
    driver: Any,
    file_path: str | Path,
    chunk_size: int = 1000,
    overlap: int = 200,
) -> Dict[str, Any]:
    """
    Reads a markdown file, splits it into overlapping chunks, extracts Wiki-style
    concepts, and saves the Note, Chunks, and Concepts to Neo4j.
    """
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"File not found: {file_path}")

    # Read file content
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    note_title = path.stem
    note_id = str(path.resolve())

    # Chunk content
    chunks = split_text(content, chunk_size, overlap)

    # Extract all concepts from full note
    file_concepts = extract_concepts(content)

    logger.info(
        "Ingesting note '%s' (%d chunks, %d concepts)...",
        note_title,
        len(chunks),
        len(file_concepts),
    )

    async with driver.session() as session:
        # 1. Merge Note node
        note_query = """
        MERGE (n:Note {id: $note_id})
        SET n.title = $title, n.source_file = $source_file
        RETURN n
        """
        await session.run(
            note_query,
            {"note_id": note_id, "title": note_title, "source_file": str(path)},
        )

        # 2. Merge Concept nodes and connect to Note via MENTIONS
        for concept_name in file_concepts:
            concept_query = """
            MERGE (c:Concept {name: $name})
            WITH c
            MATCH (n:Note {id: $note_id})
            MERGE (n)-[:MENTIONS]->(c)
            """
            await session.run(concept_query, {"name": concept_name, "note_id": note_id})

        # 3. Merge Chunk nodes and connect to Note via PART_OF, and Concepts via MENTIONS
        for idx, chunk_text in enumerate(chunks):
            chunk_id = f"{note_id}#chunk-{idx}"
            chunk_concepts = extract_concepts(chunk_text)

            # Create/Merge Chunk and connect to parent Note
            chunk_query = """
            MERGE (ch:Chunk {id: $chunk_id})
            SET ch.text = $text, ch.source_file = $source_file, ch.embedding_vector = $embedding_vector
            WITH ch
            MATCH (n:Note {id: $note_id})
            MERGE (ch)-[:PART_OF]->(n)
            """
            await session.run(
                chunk_query,
                {
                    "chunk_id": chunk_id,
                    "text": chunk_text,
                    "source_file": str(path),
                    "embedding_vector": [0.0] * 1536,  # Placeholder embedding vector
                    "note_id": note_id,
                },
            )

            # Connect Chunk to specific Concepts mentioned inside this chunk
            for concept_name in chunk_concepts:
                chunk_concept_query = """
                MATCH (ch:Chunk {id: $chunk_id})
                MATCH (c:Concept {name: $concept_name})
                MERGE (ch)-[:MENTIONS]->(c)
                """
                await session.run(
                    chunk_concept_query,
                    {"chunk_id": chunk_id, "concept_name": concept_name},
                )

    return {
        "note_id": note_id,
        "title": note_title,
        "chunks_count": len(chunks),
        "concepts_count": len(file_concepts),
    }
