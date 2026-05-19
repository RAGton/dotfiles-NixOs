import asyncio
import tempfile
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock

from kora.brain.ingestor import extract_concepts, ingest_markdown, split_text
from kora.brain.schema import init_graph


def _run(coro):
    loop = asyncio.new_event_loop()
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()


class TestBrainSchemaAndIngestor(unittest.TestCase):

    def test_split_text_valid(self):
        """split_text must divide text into chunks with correct size and overlap."""
        text = "abcdefghij"  # len 10
        # size 4, overlap 2
        # chunk 1: abcd (0 to 4)
        # chunk 2: start = 4 - 2 = 2. 2 to 6 => cdef
        # chunk 3: start = 6 - 2 = 4. 4 to 8 => efgh
        # chunk 4: start = 8 - 2 = 6. 6 to 10 => ghij
        chunks = split_text(text, chunk_size=4, overlap=2)
        self.assertEqual(chunks, ["abcd", "cdef", "efgh", "ghij"])

        # No overlap
        chunks_no_overlap = split_text(text, chunk_size=3, overlap=0)
        self.assertEqual(chunks_no_overlap, ["abc", "def", "ghi", "j"])

        # Empty string
        self.assertEqual(split_text("", 5, 2), [])

    def test_split_text_errors(self):
        """split_text must raise ValueError for invalid inputs."""
        with self.assertRaises(ValueError):
            split_text("test", chunk_size=0, overlap=2)
        with self.assertRaises(ValueError):
            split_text("test", chunk_size=5, overlap=-1)
        with self.assertRaises(ValueError):
            split_text("test", chunk_size=5, overlap=5)
        with self.assertRaises(ValueError):
            split_text("test", chunk_size=5, overlap=6)

    def test_extract_concepts(self):
        """extract_concepts must extract standard wiki links, stripping section and alias details."""
        sample_text = (
            "This is a [[Concept A]] in our vault. "
            "Here is [[Concept B|with alias]] and [[Concept C#SectionName]]. "
            "Let's not forget [[Concept D#Section|Alias]]. "
            "Duplicates should be skipped: [[Concept A]] again."
        )
        concepts = extract_concepts(sample_text)
        self.assertEqual(concepts, ["Concept A", "Concept B", "Concept C", "Concept D"])

        # Edge case: spaces inside wiki links
        self.assertEqual(extract_concepts("Hello [[  Concept Space  ]]"), ["Concept Space"])
        # No wiki links
        self.assertEqual(extract_concepts("Hello World"), [])

    def test_init_graph_schema(self):
        """init_graph must run CREATE CONSTRAINT statements against a session."""
        mock_session = AsyncMock()
        mock_session.run = AsyncMock()
        mock_session.__aenter__ = AsyncMock(return_value=mock_session)
        mock_session.__aexit__ = AsyncMock(return_value=False)

        mock_driver = MagicMock()
        mock_driver.session = MagicMock(return_value=mock_session)

        _run(init_graph(mock_driver))

        # Check constraint queries were run
        self.assertTrue(mock_session.run.called)
        first_call_query = mock_session.run.call_args_list[0].args[0]
        self.assertIn("CREATE CONSTRAINT", first_call_query)

    def test_ingest_markdown_file_not_found(self):
        """ingest_markdown must raise FileNotFoundError if target file does not exist."""
        mock_driver = MagicMock()
        with self.assertRaises(FileNotFoundError):
            _run(ingest_markdown(mock_driver, "non_existent_file.md"))

    def test_ingest_markdown_success(self):
        """ingest_markdown must read the file, split text, extract concepts, and execute correct Cypher statements."""
        mock_session = AsyncMock()
        mock_session.run = AsyncMock()
        mock_session.__aenter__ = AsyncMock(return_value=mock_session)
        mock_session.__aexit__ = AsyncMock(return_value=False)

        mock_driver = MagicMock()
        mock_driver.session = MagicMock(return_value=mock_session)

        markdown_content = (
            "# My Title\n"
            "This document is about [[NixOS]] and [[Hyprland|the window manager]].\n"
            "Here is some other text to chunk."
        )

        with tempfile.TemporaryDirectory() as tmpdir:
            file_path = Path(tmpdir) / "test_note.md"
            file_path.write_text(markdown_content, encoding="utf-8")

            # Run with size 30, overlap 10
            res = _run(ingest_markdown(mock_driver, file_path, chunk_size=30, overlap=10))

            # Validate return shape
            self.assertEqual(res["title"], "test_note")
            self.assertEqual(res["concepts_count"], 2)
            self.assertGreater(res["chunks_count"], 0)

            # Check that MERGE statements were sent to Neo4j
            run_calls = [call.args[0] for call in mock_session.run.call_args_list]
            self.assertTrue(any("MERGE (n:Note" in q for q in run_calls))
            self.assertTrue(any("MERGE (c:Concept" in q for q in run_calls))
            self.assertTrue(any("MERGE (ch:Chunk" in q for q in run_calls))


if __name__ == "__main__":
    unittest.main()
