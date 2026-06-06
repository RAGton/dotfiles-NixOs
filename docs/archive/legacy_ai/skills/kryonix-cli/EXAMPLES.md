# Exemplos: Kryonix CLI

## Diagnóstico

```sh
kryonix doctor
kryonix doctor --host glacier --verbose
```

## Consolidação de fluxo

```sh
kryonix snapshot
kryonix generations
kryonix rollback
```

## Direção prática

- se `snapshot`, `generations` ou `rollback` ainda não estiverem expostos, estenda `kryonix`
- não introduza aliases soltos ou scripts fora da CLI para cobrir esse mesmo fluxo
