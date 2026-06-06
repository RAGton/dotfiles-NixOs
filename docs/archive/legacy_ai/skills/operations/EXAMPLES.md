# Exemplos: Operations

## Validação antes de aplicar

```sh
kryonix doctor
kryonix diff
kryonix test
```

## Quando promover para aplicação direta

```sh
kryonix switch
```

## Separar erro novo de erro antigo

- repetir o comando base sem a mudança suspeita quando possível
- comparar a saída atual com o comportamento que já falhava antes
- corrigir primeiro a regressão introduzida nesta rodada
