# Aplicar o repositório no notebook da Nina sem apagar nada

Guia criado em 2026-03-19 para o host `inspiron-nina`.

Objetivo: aplicar este repositório no notebook da Nina sem formatar disco, sem rodar instalador e sem substituir o `/etc/nixos` atual.

## O que este guia não faz

Não rode nenhum destes comandos no notebook dela:

```sh
nixos-install
nix run github:nix-community/disko -- --mode disko ...
sudo disko ...
```

Esses fluxos são de instalação/particionamento. Para a Nina, a ideia aqui é só aplicar a configuração existente por cima do sistema atual.

## Pré-requisitos

- O notebook já tem `nix` instalado.
- Se for aplicar o sistema completo, o notebook precisa já estar rodando NixOS.
- Se for aplicar apenas Home Manager fora do NixOS, a usuária do sistema já precisa se chamar `nina`.

## 1. Clonar o repositório

```sh
mkdir -p "$HOME/src"
git clone https://github.com/RAGton/node-nixos "$HOME/src/node-nixos"
cd "$HOME/src/node-nixos"
nix flake show . >/dev/null
```

Esse clone pode ficar no home da Nina. Não precisa mover para `/etc/nixos`.

## 2. Descobrir se o notebook já é NixOS

```sh
if command -v nixos-rebuild >/dev/null 2>&1; then
  echo "NixOS detectado"
else
  echo "Somente Nix detectado"
fi
```

Se aparecer `Somente Nix detectado`, pule para a seção `Aplicar só Home Manager`.

## 3. Backup do `/etc/nixos` atual

Esse passo é só para NixOS.

```sh
sudo mkdir -p /var/backups/nixos
sudo cp -a /etc/nixos "/var/backups/nixos/etc-nixos-before-inspiron-nina-$(date +%F-%H%M%S)"
```

O backup fica guardado e o `/etc/nixos` atual continua intacto.

## 4. Copiar o hardware real do notebook para o host `inspiron-nina`

Esse passo é obrigatório antes de qualquer `nixos-rebuild`.

```sh
sudo cp /etc/nixos/hardware-configuration.nix ./hosts/inspiron-nina/hardware-configuration.nix
sudo chown "$USER":"$(id -gn)" ./hosts/inspiron-nina/hardware-configuration.nix
```

Depois confirme que o arquivo copiado realmente contém entradas de `fileSystems` e `swapDevices`:

```sh
rg -n 'fileSystems|swapDevices' ./hosts/inspiron-nina/hardware-configuration.nix
```

Se esse comando não mostrar nada útil, pare aqui e gere/copie o `hardware-configuration.nix` correto da máquina.

## 5. Testar a Home Manager da Nina

Esse teste é seguro e não mexe em disco.

```sh
nix build '.#homeConfigurations."nina@inspiron-nina".activationPackage'
```

Se quiser já aplicar a parte de usuário:

```sh
nix shell nixpkgs#home-manager -c home-manager switch --flake '.#nina@inspiron-nina'
```

Observação: esse passo só funciona fora do NixOS se a usuária atual do Linux for mesmo `nina`.

## 6. Testar o sistema sem ativar

Esse passo é para NixOS e ainda não troca a geração ativa:

```sh
sudo nixos-rebuild dry-build --flake '.#inspiron-nina'
```

Se aparecer erro relacionado a `fileSystems`, `swapDevices`, `PARTLABEL`, `UUID` ou `disko`, não continue para o `switch`. Corrija primeiro o `hardware-configuration.nix` dessa máquina.

## 7. Aplicar o sistema

Se o `dry-build` passou:

```sh
sudo nixos-rebuild switch --flake '.#inspiron-nina'
```

Esse comando aplica a configuração do host `inspiron-nina` sem reinstalar o sistema e sem apagar disco.

## 8. Aplicar a Home Manager depois do switch

```sh
nix shell nixpkgs#home-manager -c home-manager switch --flake '.#nina@inspiron-nina'
```

## 9. Confirmar que entrou o host certo

```sh
hostnamectl
getent passwd nina
```

O esperado é:

- hostname: `inspiron-nina`
- usuária `nina` existente
- nome completo `Nicoly Canteiro`

A senha inicial declarada no repositório é `nina`. Isso só vale para o caminho NixOS, quando o usuário passar a ser gerenciado pela configuração do sistema.

## 10. Rollback se algo der errado

Para voltar a geração anterior do sistema:

```sh
sudo nixos-rebuild switch --rollback
```

Para voltar a Home Manager:

```sh
nix shell nixpkgs#home-manager -c home-manager generations
nix shell nixpkgs#home-manager -c home-manager switch --rollback
```

## Aplicar só Home Manager

Use este caminho se o notebook não for NixOS e tiver apenas o `nix` instalado.

```sh
cd "$HOME/src/node-nixos"
nix build '.#homeConfigurations."nina@inspiron-nina".activationPackage'
nix shell nixpkgs#home-manager -c home-manager switch --flake '.#nina@inspiron-nina'
```

Limitação importante:

- isso não cria a usuária `nina`
- isso não muda boot, kernel nem serviços do NixOS
- isso não deve ser usado se a usuária atual do sistema não for `nina`

## Resumo curto

Fluxo seguro para ela:

1. Clonar o repo no home.
2. Fazer backup do `/etc/nixos` atual.
3. Copiar o `hardware-configuration.nix` real da máquina.
4. Rodar `nixos-rebuild dry-build`.
5. Só depois rodar `nixos-rebuild switch`.
6. Aplicar `home-manager switch`.

Sem instalação limpa, sem `disko` e sem apagar nada.
