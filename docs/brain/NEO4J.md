# Neo4j (Base de Dados em Grafo)

O Kryonix utiliza a edição Community do Neo4j para armazenar o grafo de conhecimento (Knowledge Graph) usado pelas estratégias de GraphRAG.

## Configuração Segura

O serviço (`modules/nixos/services/neo4j.nix`) opera sob rigorosas restrições:
1. **Network Binding:** A interface HTTP expõe apenas para `127.0.0.1` (localhost absoluto).
2. **Bolt Protocol:** Expõe em `0.0.0.0`, porém é rigidamente **barrado pelo firewall local (iptables)** permitindo apenas o CIDR da Tailscale (`100.64.0.0/10`).
3. **Sem Auth por Padrão:** Dada a blindagem total da rede, a autenticação base é desativada localmente, o que facilita enormemente as chamadas Python locais do API daemon sem necessidade de rotação de credenciais.

## Armazenamento

O Neo4j armazena seus dados canônicos em `/var/lib/kryonix/brain/neo4j/`.
É fundamental que agentes e processos nunca alterem arquivos brutos aqui, apenas consumam através das portas TCP correspondentes ou das interfaces FastAPI do Kryonix Brain.

## Tuning

Em `glacier-ai.nix`, o Neo4j recebe Tuning dinâmico:
- `pagecache`: 1GB
- `heap.initial` e `heap.max`: De 512m a 2GB, ajustado de acordo com a pressão de concorrência com o Ollama na RAM do sistema.
