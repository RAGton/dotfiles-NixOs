# Kryonix — Governança de RAG e GraphRAG

## Objetivo

Impedir que o Kryonix Brain se perca ao misturar informações do projeto, Vault, logs, conversas, artigos, vídeos e documentação externa.

## Regra principal

Nada entra no RAG como verdade sem origem, tipo, confiança, data e status.

## Fontes e prioridade

1. Código do projeto: flake.nix, hosts/, modules/, packages/
2. Documentação canônica: .ai/, docs/, README.md
3. Logs reais: journalctl, health checks, doctor
4. Vault/Obsidian
5. Conversas e decisões antigas
6. Artigos, vídeos e PDFs externos
7. Web research não revisado

## Status possíveis

- active
- draft
- approved
- deprecated
- obsolete
- experimental
- rejected

## Níveis de confiança

- canonical
- high
- medium
- low
- untrusted

## Regras de ingestão

- Código e docs canônicos podem entrar como alta confiança.
- Conteúdo externo entra como draft.
- Web research entra como untrusted até revisão.
- Conversas antigas entram como memória, não como verdade absoluta.
- Logs têm validade temporal e devem carregar timestamp.
- Nada obsoleto deve ser usado sem aviso explícito.

## Metadados obrigatórios

Todo chunk deve conter:

- id
- source_path
- source_type
- domain
- trust_level
- status
- created_at
- updated_at
- tags
- summary
- entities
- commit quando aplicável
- host quando aplicável
- service quando aplicável
- command quando aplicável

## Retrieval

O Kryonix Brain deve usar:

1. classificação da pergunta;
2. seleção de coleções;
3. busca vetorial;
4. busca textual;
5. travessia Neo4j quando houver entidade;
6. reranking por confiança;
7. resposta com fontes;
8. aviso quando não houver grounding suficiente.

## Regras de resposta

O Brain deve:

- citar fontes internas;
- distinguir fato de hipótese;
- priorizar estado atual do repo;
- avisar quando a informação vier de artigo externo;
- nunca misturar plano futuro com implementação real;
- sugerir comandos de validação quando for troubleshooting;
- não executar ação destrutiva sem confirmação humana.

## Critérios de qualidade

Uma resposta boa deve conter:

- diagnóstico provável;
- fontes usadas;
- arquivos relacionados;
- comandos de validação;
- riscos;
- próximo passo;
- nível de confiança.

