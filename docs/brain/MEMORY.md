# Camada de Memória (Obsidian)

O Kryonix não deixa a memória dos Agentes espalhada livremente em chats. O conhecimento real e persistente do usuário é estruturado em um formato suportado e lido pelo Obsidian (`/var/lib/kryonix/vault/`).

## O Vault como Fonte da Verdade

- **Vault Local:** Uma pasta de arquivos `.md` plana ou organizada.
- **Agent Integration:** Ferramentas MCP (`obsidian_search`, `obsidian_read`) permitem que Agentes de IA procurem notas, decisões antigas e rascunhos.
- **RAG Sync (Roadmap):** O pacote Python `kryonix-brain-lightrag` possui o módulo `obsidian_cli.py` projetado para indexar ativamente o diretório do vault para dentro da VectorDB e Neo4j.

## Limitações do Vault
A regra do Kryonix é explícita: **O Código Real Vence o Vault.**
Se uma nota no Obsidian disser que a porta é 8080, mas o `flake.nix` e os módulos definirem 8000, o código vence. O Obsidian é a memória de "intenções" e "projetos passados", não de estado em tempo real.
