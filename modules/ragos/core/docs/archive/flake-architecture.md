# Arquitetura do Flake

Status: archived  
Scope: Descricao historica da estrutura de flake anterior

## O que é

`flake.nix` é o ponto de entrada único do projeto RAGOS. Ele importa o runtime real do host, valida entradas e declara todas as configurações NixOS.

## Para que serve

Centralizar configuração em um único arquivo auditável e evitar IPs ou users hardcoded dispersos nos módulos.

## Estrutura

```
flake.nix
├── inputs
│   ├── nixpkgs (nixos-25.11)
│   └── flake-utils
│
├── ragosParams          — parâmetros importados de `server/runtime`
├── _check               — validações com throw explícito
├── specialArgs          — passados a server e client via nixosSystem
│
├── eachDefaultSystem    — formatter + devShell
│
└── // (merge)
    ├── ragosParams       — exposto como output para scripts
    ├── nixosConfigurations.srv-rag
    └── nixosConfigurations.ragos-client
```

## Por que nixosConfigurations fica fora do eachDefaultSystem

`eachDefaultSystem` gera outputs por sistema (ex: `x86_64-linux`, `aarch64-linux`).

Se `nixosConfigurations` fosse colocado dentro, as chaves se tornariam:
```
nixosConfigurations.x86_64-linux.srv-rag   ← INACESSÍVEL pelo nixos-rebuild
```

O correto é usar `//` para mesclar ao nível raiz:
```
nixosConfigurations.srv-rag                ← acessível corretamente
```

## Fonte dos parâmetros

```nix
ragosParams = {
  serverIp            = "192.168.100.2";    # IP do servidor na LAN
  httpPort            = 8080;               # Porta HTTP
  adminUser           = "rag";              # Nome do usuário admin
  adminUid            = 1000;              # UID do usuário admin
  adminHashedPassword = "...";             # mkpasswd -m sha-512
  adminAuthorizedKeys = [ ];               # chaves SSH (opcional)
};
```

No host instalado, a origem real é:

```text
/var/lib/ragos/runtime/params.nix
/var/lib/ragos/runtime/hardware-configuration.nix
```

## Validações

O flake valida os parâmetros imediatamente via `_check`:

```nix
_check =
  if ragosParams.serverIp == ""
    then builtins.throw "RAGOS: ragosParams.serverIp não pode ser vazio"
  else if !(builtins.isInt ragosParams.httpPort)
    then builtins.throw "RAGOS: ragosParams.httpPort deve ser um número inteiro"
  ...
  else true;
```

`builtins.seq _check specialArgs` força a avaliação das validações antes de passar `specialArgs` para os módulos.

## specialArgs

Todos os parâmetros são propagados para server e client via `specialArgs`:

```nix
specialArgs = {
  ragosServerIp            = ragosParams.serverIp;
  ragosHttpPort            = ragosParams.httpPort;
  ragosAdminUser           = ragosParams.adminUser;
  ragosAdminUid            = ragosParams.adminUid;
  ragosAdminHashedPassword = ragosParams.adminHashedPassword;
  ragosAdminAuthorizedKeys = ragosParams.adminAuthorizedKeys;
};
```

## Outputs disponíveis

```bash
# Listar outputs
nix flake show

# Acessar parâmetros via scripts
nix eval --raw .#ragosParams.serverIp
nix eval --raw .#ragosParams.httpPort

# Build servidor
nix build .#nixosConfigurations.srv-rag.config.system.build.toplevel

# Build cliente
nix build .#nixosConfigurations.ragos-client.config.system.build.toplevel
```
