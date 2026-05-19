import pytest
import time
import hashlib
from unittest.mock import AsyncMock, MagicMock, patch
from kora.core.orchestrator import _CAG_CACHE, process_message, _check_and_invalidate_cache, SimpleLRUCache
from kora.mind.mind import MindOutput

@pytest.fixture(autouse=True)
def clean_cache():
    _CAG_CACHE.clear()
    yield
    _CAG_CACHE.clear()

def test_simple_lru_cache():
    cache = SimpleLRUCache(capacity=2)
    cache.put("a", 1)
    cache.put("b", 2)
    assert cache.get("a") == 1
    
    # Exceed capacity
    cache.put("c", 3)
    assert cache.get("b") is None  # Evicted (since "a" was accessed/moved to end)
    assert cache.get("a") == 1
    assert cache.get("c") == 3

@patch("kora.integrations.brain.search")
@patch("kora.mind.mind.KoraMind.respond")
def test_cag_cache_hit_and_miss(mock_respond, mock_brain_search):
    import asyncio
    async def run():
        # Mock RAG backend search to return success
        mock_brain_search.return_value = {
            "status": "success",
            "answer": "O Glacier é o servidor IA do Kryonix [glacier.md].",
            "sources": [{"file": "glacier.md"}]
        }
        
        # Mock KoraMind response with valid citation to satisfy QualityGuard
        mock_respond.return_value = MindOutput(answer="O Glacier é o servidor IA [glacier.md].")

        query = "O que é o Glacier?"
        
        # First request: should be a cache miss, calling KoraMind
        res1 = await process_message(
            message=query,
            session_id="test_session",
            user="rocha",
            mode="rag"
        )
        
        assert res1["answer"] == "O Glacier é o servidor IA [glacier.md]."
        assert res1["brain_used"] is True
        assert res1["model"] == "kora-mind"
        assert mock_respond.call_count == 1
        
        # Verify cache has the entry
        cache_key = hashlib.sha256(query.encode()).hexdigest()
        assert _CAG_CACHE.get(cache_key) is not None
        
        # Second request: should hit cache
        res2 = await process_message(
            message=query,
            session_id="test_session",
            user="rocha",
            mode="rag"
        )
        
        assert res2["answer"] == "O Glacier é o servidor IA [glacier.md]."
        assert res2["brain_used"] is True
        assert res2["model"] == "kora-cag-cache"
        # Call count of KoraMind should still be 1 (meaning it was not called again)
        assert mock_respond.call_count == 1
    asyncio.run(run())

@patch("kora.integrations.brain.search")
@patch("kora.mind.mind.KoraMind.respond")
@patch("kora.core.orchestrator.Path")
def test_cag_cache_invalidation_on_mtime(mock_path_class, mock_respond, mock_brain_search):
    import asyncio
    async def run():
        # Setup the isolated mock Path object
        mock_path_instance = MagicMock()
        mock_path_instance.exists.return_value = True
        
        stat_mock = MagicMock()
        stat_mock.st_mtime = 1000.0
        mock_path_instance.stat.return_value = stat_mock
        
        mock_path_class.return_value = mock_path_instance

        # Reset last mtime tracker logic
        import kora.core.orchestrator
        kora.core.orchestrator._LAST_GRAPH_MTIME = 0.0
        
        # Initialize the last mtime tracker inside orchestrator
        _check_and_invalidate_cache()
        assert kora.core.orchestrator._LAST_GRAPH_MTIME == 1000.0
        
        # Mock RAG backend search and KoraMind response
        mock_brain_search.return_value = {
            "status": "success",
            "answer": "O Glacier é o servidor IA [glacier.md].",
            "sources": [{"file": "glacier.md"}]
        }
        mock_respond.return_value = MindOutput(answer="O Glacier é o servidor IA [glacier.md].")
        
        query = "O que é o Glacier?"
        
        # Perform first request -> Cache miss, cached
        res1 = await process_message(message=query, mode="rag")
        assert res1["model"] == "kora-mind"
        
        # Perform second request -> Cache hit
        res2 = await process_message(message=query, mode="rag")
        assert res2["model"] == "kora-cag-cache"
        
        # Now simulate index update (mtime changes)
        stat_mock.st_mtime = 1005.0
        
        # Third request -> Cache should be cleared due to rebuild detection, so cache miss again
        res3 = await process_message(message=query, mode="rag")
        assert res3["model"] == "kora-mind"
    asyncio.run(run())
