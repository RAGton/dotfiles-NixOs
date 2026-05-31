# Current State - Kryonix 🧊⚡

- **Fase Atual:** Estabilização v0.5.0 e Automação de Governança (Fase 4B do Autopilot).
- **Arquitetura:** 
    - **Inspiron:** Workstation cliente, Hyprland/Caelestia, CLI local.
    - **Glacier:** Servidor IA, Brain API, Neo4j, Ollama (IP `100.125.99.110`, SSH `2224`).
- **Estado do Repo:** 
    - Sincronizado e limpo. 
    - Registry v2 100% normalizado (Schema Version 2).
- **CLI & Operações:**
    - **Registry v2:** Normalizado com metadados rigorosos (`critical` risk level, `requires_runtime` array).
    - **Help:** Visual polido, suporte a cores para riscos críticos e alertas de sudo.
    - **Validadores:** `check-kryonix-cli-help.sh` agora valida contrato JSON v2.
- **Brain & AI:**
    - **Health:** API e Storage estáveis no Glacier.
    - **Registry Integration:** Ingestão do Registry v2 no grafo 100% implementada e persistida no Neo4j do Glacier (26 comandos principais mapeados).
    - **Safe Autopilot (Fase 4B):** Camada de autorização e simulação implementada. `apply` agora exige `--proposal` e `approve`, valida host (Glacier para storage), comandos (Registry v2), risco (bloqueia critical) e termos destrutivos.
- **Próxima Meta:** Ingestão de logs técnicos e eventos históricos no Knowledge Graph e Fase 4C (Apply Real).
- **Bloqueios:** Nenhum.

## Decisões Recentes
- **Neo4j/Graph somente no Glacier**: Toda geração final de manifesto, dry-run oficial, apply e validação de escrita no Neo4j deve ocorrer no Glacier. Inspiron atua como cliente de desenvolvimento e consulta.
- **Registry v2 como Contrato**: O `kryonix commands --json` é o contrato formal para o Knowledge Graph.
- **MCP Decoupled**: `kryonix mcp check` e `kryonix mcp doctor` desacoplados do runtime do RAG local no Inspiron. No cliente, a validação é focada em segurança, syntax e paths (via `scripts/check-mcp.sh`).
- **MCP Quality Layer**: Implementado servidor MCP Read-Only expondo recursos canônicos e ferramentas de diagnóstico sem exposição de segredos ou ações destrutivas (Issue #51 concluída).
- **Safe Autopilot Loop**: Implementado o subsistema de melhoria autônoma segura (`autopilot`, `autopilot_graph`, `autopilot_rag`, `autopilot_cag`, `autopilot_lightrag`) em conformidade com as restrições da Issue #52.
- **Autopilot Authorization Layer (Phase 4B):** Implementado fluxo seguro `approve` -> `apply --proposal <id>` com 12 guardrails e auditoria JSONL (Issue #53 concluída).

*Última atualização: 2026-05-14 por Antigravity*
