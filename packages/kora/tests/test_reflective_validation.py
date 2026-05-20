import pytest
from pathlib import Path
import json
import shutil
from kora.core.orchestrator import process_message

class MockOllamaAdapter:
    async def generate(self, prompt, system_prompt):
        if "duckduckgo" in prompt.lower() or "extraia uma única frase" in prompt.lower():
            return "ollama port numbers"
        elif "afirmação do usuário" in prompt.lower():
            return json.dumps({
                "verified": False,
                "has_conflict": True,
                "factual_explanation": "A porta padrão do Ollama é 11434.",
                "warning_message": "Ragton, verifiquei na internet e encontrei que a porta padrão do Ollama é 11434. Você tem certeza sobre a porta 12345?"
            })
        elif "extraia aprendizados úteis" in prompt.lower() or "spelling_mappings" in prompt:
            return json.dumps({
                "spelling_mappings": {},
                "new_vocabulary": [],
                "active_projects": [],
                "preferences": []
            })
        return "{}"

@pytest.mark.anyio
async def test_reflective_validation_trigger(monkeypatch):
    from kora.llm.ollama import OllamaAdapter
    monkeypatch.setattr(OllamaAdapter, "generate", MockOllamaAdapter.generate)

    # Mock DuckDuckGo search
    async def mock_google_search(query):
        return "[1] A porta padrão do Ollama é 11434."
    monkeypatch.setattr("kora.llm.tools._exec_google_search", mock_google_search)

    # Clean any staged pending fact
    pending_file = Path("/var/lib/kryonix/kora/memory/pending_fact.json")
    if pending_file.exists():
        pending_file.unlink()

    # Message triggering reflective validation
    msg = "você está errado, o Ollama roda na porta 12345"
    res = await process_message(msg, user="rocha")

    assert "porta 12345" in res["answer"]
    assert pending_file.exists()

    # Message confirming
    res_confirm = await process_message("sim, tenho certeza", user="rocha")
    assert "gravei essa informação" in res_confirm["answer"] or "atualizei minha memória" in res_confirm["answer"]
    assert not pending_file.exists()
