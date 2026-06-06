# Kryonix AI State - 🧊⚡

- **Objetivo atual**: Estabilização v0.5.0 e Automação de Governança.
- **Último passo concluído**: **Registry v2** implementado. (2026-05-14T09:35:00Z)
  - CLI `kryonix commands --json` agora fornece metadados de risco e host.
  - Sincronização operacional Glacier/Inspiron validada via SSH porta 2224.
  - Limpeza de artefatos de build e resíduos no repo.
- **Estado anterior**: Acesso Remoto WayVNC seguro implementado e validado. (2026-05-07)
- **Infraestrutura IA**:
    - **Glacier (Server)**: RTX 4060, Ollama + Brain API + Neo4j.
    - **Inspiron (Client)**: Acesso via CLI remota.
- **Storage canônico**: `/var/lib/kryonix/brain/storage` ✅
- **Vault canônico**: `/home/rocha/.local/share/kryonix/kryonix-vault` ✅
- **Status do Brain**: ESTÁVEL (Health OK, Search/Ask OK).
- **Modelos**: `nomic-embed-text`, `qwen2.5-coder`, `llama3.1:8b`.
- **Próximos passos**:
  1. Integrar Registry v2 no grafo do Brain (Grounding Operacional).
  2. Implementar Autocura do Vault (Doctor local).
  3. Expandir documentação de Shortcuts e UX.

*Última atualização: 2026-05-14T09:38:00Z*
