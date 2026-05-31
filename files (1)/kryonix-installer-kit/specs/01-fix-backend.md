# Spec 01 — Fix: Backend Axum

Implementar após diagnóstico apontar o erro específico no backend.

## Problemas comuns
- **Cargo.toml desatualizado**: deps versão incompatível.
- **Main.rs não builda**: error handling, async/await, imports.
- **Binding de porta**: PORT env var não lido, 8080 já ocupado, listen address errado.

## Implementação
1. Diagnosticar exato (ver Spec 00).
2. Ler código do main.rs (capture atual, não alucine).
3. Corrigir — pequenos PRs, validar com `cargo build --release`.
4. Rodar em VM pós-build.

## Validação
```bash
cargo build --release && echo "✓ Compila"
./target/release/kryonix-installer &
sleep 2
curl http://localhost:8080/api/health && echo "✓ Responde"
kill %1
```
