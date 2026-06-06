---
source: docs/ROADMAP.md
status: derived
canonical: false
last_sync: 2026-05-01
---

# Roadmap do Kryonix

> [!IMPORTANT]
> Esta nota é derivada de `docs/`. Em caso de divergência, `docs/` vence.

Este documento contém o planejamento futuro do projeto Kryonix. O repositório segue rigorosamente o princípio da "Verdade Operacional". Tudo que não possui validação runtime real comprovável encontra-se aqui.

---

## Kryonix Brain API

STATUS: NOT_IMPLEMENTED

DESCRIÇÃO:
API central do Kryonix Brain para centralizar o processamento do LightRAG e LLM operations, abstraindo a IA do host cliente (`inspiron`).

EVIDÊNCIA ATUAL:
- Serviço systemd existente: `kryonix-brain-api.service` (atualmente inativo/morto).

GAPS:
- O serviço não roda nativamente de modo persistente.
- A porta `8000` não se encontra exposta e respondendo ativamente.
- O daemon falha ou não tem script de `ExecStart` plenamente validado e robusto no NixOS.

CRITÉRIO DE CONCLUSÃO (OBRIGATÓRIO):
- impacto documentado em ARCHITECTURE.md ou USAGE.md
- systemd service `kryonix-brain-api` ativo e em estado `running`.
- porta `8000` aberta em localhost ou LAN.
- endpoint `GET /health` respondendo 200 OK.

COMANDOS DE VALIDAÇÃO:
```sh
systemctl status kryonix-brain-api.service --no-pager
ss -ltnp | grep 8000
curl -sf http://localhost:8000/health
```

RISCOS:
- Inconsistência de acesso concorrente ao banco de vetores.
- Exposição indevida do storage via API HTTP.

---

## MCP Remoto Completo

STATUS: PARTIAL

DESCRIÇÃO:
Suporte pleno ao Model Context Protocol conectando agentes ao Kryonix de forma remota, com discovery automático de ferramentas do servidor.

EVIDÊNCIA ATUAL:
- `kryonix mcp` no CLI está parcialmente implementado em `.mcp.example.json`.
- Tools locais documentadas (mcp-nixos, filesystem).

GAPS:
- Ferramentas de servidor (como `rag_search` e `graph_heal`) não foram validadas no runtime do Glacier via MCP.
- Sem comprovação de conexão segura persistente entre Inspiron e a sessão SSH que inicializa o MCP do Brain.

CRITÉRIO DE CONCLUSÃO (OBRIGATÓRIO):
- impacto documentado em ARCHITECTURE.md ou USAGE.md
- O CLI `kryonix mcp doctor` retornar status OK (sem falhas de timeout ou paths incorretos) validando o servidor do Glacier.
- Retorno JSON-RPC com as `tools` ativas na interface do Claude/Cursor.

COMANDOS DE VALIDAÇÃO:
```sh
kryonix mcp doctor
kryonix mcp check
```

RISCOS:
- Vazamento de secrets no JSON-RPC.
- Timeout no boot-up do virtualenv/python via SSH.

---

## Glacier NixOS Definitivo (Autônomo)

STATUS: PARTIAL

DESCRIÇÃO:
Consolidação do Glacier como backend headless autônomo. O gerenciamento das cargas de inteligência deve inicializar automaticamente independente do login gráfico.

EVIDÊNCIA ATUAL:
- Host profile presente em `hosts/glacier`.
- `ollama.service` funcional.

GAPS:
- Serviços dependentes do usuário logado ao invés do boot system (falta de isolamento autônomo pleno).

CRITÉRIO DE CONCLUSÃO (OBRIGATÓRIO):
- impacto documentado em ARCHITECTURE.md ou USAGE.md
- O Glacier conseguir inicializar e servir `Ollama`, `Tailscale` e `Brain API` sem necessidade de login manual (apenas boot).

COMANDOS DE VALIDAÇÃO:
```sh
kryonix test server
```

RISCOS:
- Dependência de montagem de drives criptografados manuais que impedem serviços no boot.

---

## Web Research Controlado

STATUS: NOT_IMPLEMENTED

DESCRIÇÃO:
Agentes locais com acesso seguro à internet para pesquisa e ingestão, rodando sob restrições de rede e sandbox rigorosas.

EVIDÊNCIA ATUAL:
- Nenhuma ferramenta MCP de web-search ativa.
- Nenhum container ou `bwrap` isolado para o RAG web scrape atrelado.

GAPS:
- Todo o pipeline de ingestão e parse de HTML para Markdown do LightRAG na nuvem local.

CRITÉRIO DE CONCLUSÃO (OBRIGATÓRIO):
- impacto documentado em ARCHITECTURE.md ou USAGE.md
- Serviço / CLI atrelado ao `kryonix brain ingest-web <url>` funcional.
- Sandboxing efetivo comprovado na extração.

COMANDOS DE VALIDAÇÃO:
```sh
kryonix brain ingest-web "https://nixos.org"
```

RISCOS:
- Scraping executado como processo não-sandbox, abrindo brechas de injeção direta no Vault/Graph.

---

## Geração de Pacotes com IA

STATUS: NOT_IMPLEMENTED

DESCRIÇÃO:
Pipelines LLM injetando de forma autônoma receitas ou scripts Nix na flake para empacotar softwares não mantidos pelo upstream.

EVIDÊNCIA ATUAL:
- Nada presente no repositório.

GAPS:
- Infraestrutura completa de review, syntax-check automático e git-commit via agentes.

CRITÉRIO DE CONCLUSÃO (OBRIGATÓRIO):
- impacto documentado em ARCHITECTURE.md ou USAGE.md
- Agente ser capaz de criar um `.nix` novo, formatar via `nix fmt` e aprovar em `nix flake check`.

COMANDOS DE VALIDAÇÃO:
```sh
kryonix agent package-gen "nome-do-pacote"
```

RISCOS:
- Corrupção da flake inteira por geração arbitrária de arquivos `default.nix`.

---

## Autocuradoria do Vault

STATUS: NOT_IMPLEMENTED

DESCRIÇÃO:
Processos automáticos do Brain avaliando e reorganizando notas no Vault baseados na relevância, deletando documentação obsoleta internamente.

EVIDÊNCIA ATUAL:
- A CLI `kryonix vault scan` apenas reporta integridade básica.

GAPS:
- Nenhum job assíncrono indexando metadados de stale notes.

CRITÉRIO DE CONCLUSÃO (OBRIGATÓRIO):
- impacto documentado em ARCHITECTURE.md ou USAGE.md
- Comando CLI ou timer systemd validando e listando notas marcadas para deleção via LLM.

COMANDOS DE VALIDAÇÃO:
```sh
kryonix vault curate --dry-run
```

RISCOS:
- Destruição de conhecimento permanente devido à alucinação de irrelevância pela LLM.

---

## ISO Instalável Kryonix

STATUS: NOT_IMPLEMENTED

DESCRIÇÃO:
Sistema de build em CI/CD ou local para gerar uma ISO standalone (USB bootable) para deploy da distro Kryonix.

EVIDÊNCIA ATUAL:
- Declaração `iso` incompleta no flake (falha de checagem/build).

GAPS:
- O módulo de provisionamento e live-cd com o desktop básico.

CRITÉRIO DE CONCLUSÃO (OBRIGATÓRIO):
- impacto documentado em ARCHITECTURE.md ou USAGE.md
- Comando CLI conseguir gerar um arquivo `kryonix.iso`.

COMANDOS DE VALIDAÇÃO:
```sh
kryonix iso
```

RISCOS:
- Inclusão indevida de secrets (chaves ssh, senhas do host master) dentro da ISO gerada.
