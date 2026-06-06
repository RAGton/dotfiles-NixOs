---
source: docs/OPERATIONS.md
status: derived
canonical: false
last_sync: 2026-05-01
---

# Operações Kryonix

> [!IMPORTANT]
> Esta nota é derivada de `docs/`. Em caso de divergência, `docs/` vence.

**Atualizado em:** 2026-05-01

## Fluxo oficial

A CLI `kryonix` é o ponto de entrada operacional do projeto. O fluxo oficial é NixOS/Linux, com checkout em `/etc/kryonix` nos hosts instalados.

## Resolução da flake

A origem da flake segue esta ordem:

1. `--flake <path|uri>` informado no comando
2. variável de ambiente `KRYONIX_FLAKE`
3. checkout local do Kryonix no diretório atual ou pai
4. `/etc/kryonix/flake.nix`, quando o sistema já foi instalado
5. erro com instrução clara para informar a flake manualmente

## Fluxo de Atualização de Host (Recomendado)

O fluxo seguro para testar e aplicar mudanças no Glacier ou Inspiron:

1. Modifique a configuração do repositório em `/etc/kryonix`.
2. `kryonix git-status` (Verifique as mudanças)
3. `kryonix fmt` (Formate)
4. `kryonix check` (Valide flake)
5. `kryonix diff` (Revise as diferenças)
6. `kryonix test` (Teste em runtime)
7. `kryonix boot` (Agende proximo boot) ou `kryonix switch` (Aplique agora).

## Observações

- Fora do checkout local, a CLI usa `/etc/kryonix` como origem padrão instalada.
- `/etc/kryonix` deve ser um checkout Git (preferencialmente branch main) com origem válida.
- `kryonix git-status` é o preflight obrigatório.
- Validações profundas remotas dependem que o host `glacier` esteja disponível via LAN/Tailscale.
