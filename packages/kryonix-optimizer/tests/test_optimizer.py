import pytest
import asyncio
import httpx
from unittest.mock import patch, MagicMock

from kryonix_optimizer.main import execute_safely, ask_local_slm_optimizer

@pytest.mark.asyncio
async def test_execute_safely_blocks_kill_9():
    with patch('asyncio.create_subprocess_exec') as mock_exec:
        # Tries to mock a process that returns success
        mock_proc = MagicMock()
        async def mock_communicate(): return (b"", b"")
        mock_proc.communicate = mock_communicate
        mock_exec.return_value = mock_proc
        
        # Kill -9
        await execute_safely("kill -9 123")
        mock_exec.assert_not_called()
        
        # Kill -STOP
        await execute_safely("kill -STOP 125")
        mock_exec.assert_called_once_with(
            "kill", "-STOP", "125",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )

@pytest.mark.asyncio
async def test_ask_local_slm_optimizer_offline():
    # Simulates httpx.ConnectError
    with patch('httpx.AsyncClient.post', side_effect=httpx.ConnectError("Connection refused")):
        # Retorna lista vazia e suprime exceção internamente
        result = await ask_local_slm_optimizer("vscodium", [])
        assert result == []

@pytest.mark.asyncio
async def test_ask_local_slm_optimizer_timeout():
    # Simulates httpx.TimeoutException
    with patch('httpx.AsyncClient.post', side_effect=httpx.TimeoutException("Timeout")):
        # Retorna lista vazia e suprime exceção internamente
        result = await ask_local_slm_optimizer("vscodium", [])
        assert result == []
