---
source: docs/TESTING.md
status: derived
canonical: false
last_sync: 2026-05-01
---

# Testes e Validação no Kryonix

> [!IMPORTANT]
> Esta nota é derivada de `docs/`. Em caso de divergência, `docs/` vence.

A regra de ouro do Kryonix é nunca aplicar configurações arriscadas sem uma validação prévia correspondente ao risco. Se algo quebra, não diga que está "pronto".

## Comandos de Validação Básica

- **Nix formatting**:
  ```sh
  nix fmt
  ```
- **Avaliação Geral do flake** (checa parsing e coerência):
  ```sh
  nix flake show --all-systems
  ```
- **Baseline CI** (verificação aprofundada):
  ```sh
  nix flake check --keep-going
  ```

## Operações Seguras de Validação de Configuração

Quando alterar código e quiser verificar sem arriscar o boot atual, utilize:
```sh
kryonix test
```

Este comando levanta o novo serviço no runtime do sistema (`switch-to-configuration test`). As mudanças não persistirão caso ocorra reinicialização do sistema. Ele é ideal antes do uso do `kryonix boot` ou `kryonix switch`.

Para um build de sistema limpo e completo sem aplicá-lo:
```sh
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel --no-link -L --show-trace
```

## Testes Automatizados da Infraestrutura e Brain (Cliente/Servidor)

No host `inspiron` (cliente):
```sh
kryonix test client
kryonix test mcp
kryonix test all
```
*Atenção*: Testes no cliente não devem falhar se o Glacier estiver offline, apenas exibem `WARN`.

No host `glacier` (servidor IA):
```sh
kryonix test server
```
Testa o estado da infraestrutura de IA rodando nativamente: Ollama, serviços do Kryonix Brain, etc.

## Testes via MCP e Vault

- O comando `kryonix mcp check` valida configurações (`.mcp.json`) e secrets ausentes.
- `./scripts/check-mcp.sh` avalia a existência e sintaxe local.
- Para checar integridade e links no Vault:
  ```sh
  kryonix vault scan
  kryonix vault index
  ```

## Validação de Documentação

- Para garantir que a documentação técnica corresponde perfeitamente ao estado do runtime, execute o script de auditoria:
  ```sh
  ./scripts/doc-audit.sh
  ```
  Ou, utilize o diagnóstico completo integrado:
  ```sh
  kryonix doctor full
  ```
**Regra Oficial**: A documentação só é considerada válida e pode receber merge se este script de auditoria passar com sucesso sem apontar GAPs de execução ou promessas futuras no meio da documentação canônica (termos de work-in-progress).

## Evidência de Execução

Cada validação deve registrar:

- data/hora
- host
- comando executado
- output resumido
- status: PASS/WARN/FAIL

Modelo:

```txt
[YYYY-MM-DD HH:MM | host]
$ comando
output resumido

STATUS: PASS
```

Evidências longas devem ser colocadas em `docs/evidence/`.
