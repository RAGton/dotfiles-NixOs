# Spec 03 — CI/CD + Cachix

## Estado atual (verificado)
CI com Determinate Nix (.github/workflows/ci.yml): jobs nix/shell/rust-home/python-brain/security.
SEM cache binário — cada switch recompila. allowUnfree=true.

## Objetivos
- `.github/workflows/build.yml` builda derivações pesadas e dá push p/ kryonix.cachix.org.
- Hosts e flake configurados como consumidores (substituter + chave pública).
## Plano incremental
1. Criar cache + CACHIX_AUTH_TOKEN (secret) + chave pública no flake/hosts.
2. build.yml (push em main/manual, pushFilter, matriz pesada, cachix watch-exec).
3. Validar pull em host limpo; medir tempo switch antes/depois.

## Segurança
Token só via secret; glacier toplevel sem brain.env no closure; CUDA unfree → checar licença/cache privado.
## Risco / Rollback
Chave errada → builds rejeitados; rollback = remover substituter.
