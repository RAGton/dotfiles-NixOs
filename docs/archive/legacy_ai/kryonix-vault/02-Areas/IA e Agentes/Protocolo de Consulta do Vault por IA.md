# Protocolo de Consulta do Vault por IA

## Objetivo

Definir como qualquer IA, Codex, agente local, Cursor, Claude Code, ChatGPT ou ferramenta MCP deve consultar este vault antes de responder ou alterar código.

## Prioridade de contexto

```txt
1. Projeto atual
2. Kryonix Vault
3. Documentação oficial atual
4. Código existente
5. Memória do modelo
```

Se houver conflito, priorize a fonte mais específica e verificável.

## Arquivos obrigatórios para leitura inicial

- [[README]]
- [[01-Canonical/Agents|AGENTS.md]]
- [[PROMPT_MASTER]]
- [[IMPLEMENTAR_EM_OUTROS_PROJETOS]]
- [[01-MOCs/Mapa - Cerebro Supremo de IA]]

## Fluxo obrigatório

1. Identificar domínio da tarefa.
2. Abrir o MOC relacionado.
3. Ler playbook ou Skill correspondente.
4. Ler contexto local do projeto.
5. Criar plano curto.
6. Executar menor mudança correta.
7. Validar com testes/checks.
8. Relatar riscos restantes.

## Domínios e arquivos

| Domínio | Entrada |
|---|---|
| Backend/API | [[07-Prompts/PROMPT_AGENT_BACKEND_API]] |
| Frontend moderno | [[07-Prompts/PROMPT_AGENT_SITE_MODERNO]] |
| Linux/NixOS/Proxmox | [[07-Prompts/PROMPT_AGENT_INFRA_LINUX]] |
| Pesquisa profunda | [[07-Prompts/PROMPT_SUPREMO_DEEP_RESEARCH]] |
| IA consumindo Obsidian | [[07-Prompts/PROMPT_IA_CONSUMIR_OBSIDIAN]] |

## Regras de segurança

A IA não deve executar sem confirmação humana:

- deploy em produção;
- migration destrutiva;
- alteração de secrets;
- alteração de firewall;
- alteração de boot/kernel;
- remoção de dados;
- mudança de autorização;
- alteração de billing/pagamentos.

## Saída esperada da IA

Toda resposta operacional deve conter:

- diagnóstico;
- plano;
- arquivos tocados;
- comandos de validação;
- riscos;
- rollback quando aplicável;
- próximos passos.
