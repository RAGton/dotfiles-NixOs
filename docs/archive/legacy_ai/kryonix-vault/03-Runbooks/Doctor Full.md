# Runbook: Doctor Full

Procedimento de diagnóstico completo do sistema e documentação.

## Quando usar
- Antes de cada merge/PR.
- Após mudanças estruturais no NixOS.
- Quando houver suspeita de dessincronização entre docs e runtime.

## Procedimento
Execute o comando na raiz do repositório:
```sh
kryonix doctor full
```

## O que ele valida
1. Integridade da Flake.
2. Presença de arquivos de governança.
3. Termos proibidos (TODO, WIP) em docs canônicas.
4. Vitalidade de serviços (Ollama).
5. Comandos do `USAGE.md`.

## Em caso de falha
1. Verifique o output específico do `doc-audit.sh`.
2. Corrija a divergência apontada.
3. Não faça o merge enquanto o check não estiver verde.
