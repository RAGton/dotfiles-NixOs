# Estado Atual — Kryonix Brain Rust Migration

## Alterações feitas

- **Arquivos modificados**:
  - `packages/kryonix-brain-lightrag/kryonix_brain_lightrag/rag.py`: Refatoração para tipagem e qualidade.
  - `packages/kryonix-brain-lightrag/kryonix_brain_lightrag/api.py`: Adição de métricas Prometheus e `trace_id`.
  - `packages/kryonix-brain-lightrag/kryonix_brain_lightrag/utils.py`: Melhoria no `SecretScanner` Python.
  - `packages/kryonix-brain-lightrag/pyproject.toml`: Adição de dependências e configuração (revertido backend para hatchling).
  - `packages/kryonix-brain-lightrag/shell.nix`: Configuração de ambiente Rust/Nix.
  - `packages/kryonix-brain-lightrag/Cargo.toml`: Definição de dependências Rust e alvos (bin/lib).

- **Módulos criados**:
  - `packages/kryonix-brain-lightrag/rust-core/src/lib.rs`: Lógica de expansão de grafo multi-hop.
  - `packages/kryonix-brain-lightrag/rust-core/src/main.rs`: Servidor Axum experimental.
  - `packages/kryonix-brain-lightrag/rust-core/src/utils.rs`: Scanner de segredos em Rust.

- **Testes adicionados**:
  - `packages/kryonix-brain-lightrag/tests/test_utils.py`: Testes unitários para utilitários Python.

- **Comandos executados**:
  - `uv sync`
  - `cargo build` (com falha de linking)
  - `pytest`

## O que está estável

- **FastAPI**: Continua sendo o ponto de entrada principal do serviço.
- **rag.py**: Funcional com melhorias de tipagem e lógica.
- **Métricas**: `/metrics` integrado no FastAPI via `prometheus-client`.
- **trace_id**: Presente nos logs e respostas de busca.
- **SecretScanner Python**: Validado e em uso no FastAPI.
- **Testes Python**: `test_utils.py` passando (4/4).

## O que está experimental

- **Axum server**: Implementado mas não operacional devido ao build.
- **PyO3 bridge**: Tentativa de integração com Python 3.13 no NixOS.
- **Async bridge Rust/Python**: Conceitual em `main.rs`.
- **Rust multi-hop graph**: Implementado em `lib.rs` mas requer build estável.

## Problemas encontrados

- **Erro de linking**: `cannot find -lpython3.13`. O linker não localiza a lib do Python 3.13 no ambiente Nix durante o build do binário standalone.
- **Problema de shell.nix**: Necessita de configuração mais robusta para expor caminhos de biblioteca dinâmicos.
- **Cargo.toml**: Dependência de PyO3 sem ABI estável forçada gera instabilidade em sistemas com Python >= 3.13.

## Decisão técnica

1. **Manter Python/FastAPI como produção**: O serviço NixOS continuará apontando para `uv run python -m kryonix_brain_lightrag.api`.
2. **Manter Rust como ferramentas determinísticas**: Focar em binários que não dependem de PyO3 para tarefas de manutenção (ex: `vault-scan`).
3. **Isolar Axum/PyO3**: Mover para feature flags no Cargo.toml para que o build padrão (`default`) passe sem essas dependências.
