import pytest
from pathlib import Path
import json
from kryonix_optimizer.context_binder import update_os_context, CONTEXT_FILE

@pytest.mark.asyncio
async def test_context_generation_success(tmp_path, monkeypatch):
    # Mock do ficheiro de contexto para apontar para a pasta temporária do teste
    test_context_file = tmp_path / "kryonix_context.json"
    monkeypatch.setattr("kryonix_optimizer.context_binder.CONTEXT_FILE", test_context_file)
    
    # Payload simulado do Hyprland activewindow
    hyprland_mock_output = b'{"pid": 1234, "class": "vscodium", "title": "default.nix - kryonix"}'
    
    await update_os_context(hyprland_mock_output)
    
    assert test_context_file.exists()
    with open(test_context_file) as f:
        data = json.load(f)
        assert data["active_app"] == "vscodium"
        assert data["inferred_project_tag"] == "kryonix-infra"
