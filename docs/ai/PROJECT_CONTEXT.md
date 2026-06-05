# Contexto do Projeto para Agentes IA

Você está operando no ecossistema Kryonix. Leia e siga estas regras estritamente para não corromper o sistema ou alucinar recursos.

## 1. O Motor vs As Instâncias (Dual-Flake)
O Kryonix não tem configuração de hardware real no repositório Upstream.
- **Upstream (Onde você está: `/etc/kryonix`):** É o motor. Contém módulos reaproveitáveis, features, pacotes, e perfis.
- **Downstream (Ausente aqui: `/etc/kryonixos`):** É o Superflake do usuário que importa o motor para montar máquinas reais (`inspiron`, `glacier`).

**Regra de Ouro:** Não tente criar ou editar `hosts/glacier/` no upstream, ele não existe aqui. Não crie uma pasta `home/` na raiz, as configurações de usuário vivem em `users/` no downstream.

## 2. Precedência de Verdade
1. O Código Real (Módulos, Nix files) é a fonte de verdade absoluta.
2. `docs/CURRENT_STATE.md` diz o que realmente está pronto.
3. Se um documento (mesmo em Obsidian ou `ROADMAP.md`) afirmar algo que contradiz o código, assuma que a doc está velha ou trata-se de um desejo futuro. Não documente como "pronto" o que falta implementação.

## 3. Segurança Inviolável
1. Nunca modifique, imprima, ou inclua secrets (chaves de API, senhas).
2. O arquivo `.mcp.json` é gitignored propositalmente para guardar secrets.
3. Não rode comandos destrutivos sem aprovação expressa (ex: `nixos-rebuild switch`, scripts `mkfs`).
4. Nunca modifique o `flake.lock` manualmente.

## 4. O Cérebro (Kryonix Brain)
- O motor de IA é nativo e reside em `modules/nixos/services/brain.nix` e `packages/kryonix-brain-lightrag`.
- O host Glacier age como Servidor (Roda Ollama + API FastAPI + Neo4j na Tailscale).
- O host Inspiron age como Cliente (Acessa o Glacier remotamente via túnel SSH).

## Onde Ir Próximo?
- [Índice do Projeto](PROJECT_INDEX.md)
- [Estado Operacional Atual](PROJECT_MEMORY_CURRENT.md)
- [Escopo do Agente](AGENT_SCOPE.md)
