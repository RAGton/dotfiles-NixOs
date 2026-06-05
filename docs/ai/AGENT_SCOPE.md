# Escopo de Agentes (Claude/Codex/Antigravity)

Todos os agentes de IA que operam no Kryonix devem respeitar as fronteiras abaixo. Desvios resultarão em interrupção do workflow pelo operador humano.

## O Que Você DEVE Fazer
- Ler `docs/CURRENT_STATE.md` antes de implementar features dependentes.
- Escrever código **declarativo puro**, evitando mutações de estado via bash em scripts (quando houver via nativa do Nix).
- Apresentar planos de impacto antes de invocar `sed` massivos.
- Em caso de dúvida sobre qual host hospeda um serviço, consulte a Arquitetura Dual-Flake no `README.md`.

## O Que Você NÃO PODE Fazer
- Ignorar o `.gitignore` ou injetar secrets em código rastreado (como o `.mcp.json` ou chaves de Ollama).
- Documentar em manuais ou roadmaps recursos que você apenas "imagina" que existem, baseando-se em commits avulsos sem olhar a base real.
- Executar updates de flake (`nix flake update`) sem ser instruído explícitamente. A quebra massiva de lock file paralisa a CI.
- Adicionar ou alterar partições (`disko.nix`) no upstream achando que vai formatar a máquina do operador (Lembre-se, hardware real vive no downstream).

## Falhas de Raciocínio (Hallucination traps)
- *Armadilha:* Tentar consertar um "erro" na pasta `home/` da raiz.
- *Realidade:* Essa pasta não existe no motor, ela foi descontinuada em prol de `users/` no downstream.
- *Armadilha:* Mudar IPs para `0.0.0.0` globais para "facilitar".
- *Realidade:* Tudo aqui deve estar preso a `127.0.0.1` ou Tailsacle (`100.64.0.0/10`).
