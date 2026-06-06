---
source: docs/INSTALL.md
status: derived
canonical: false
last_sync: 2026-05-01
---

# Instalação Kryonix

> [!IMPORTANT]
> Esta nota é derivada de `docs/`. Em caso de divergência, `docs/` vence.

Este documento define os passos práticos para instalar ou configurar um ambiente Kryonix atual.

## Instalação Básica

1. Obtenha o repositório em `/etc/kryonix` (ou um caminho customizado no seu home):

```sh
git clone https://github.com/RAGton/kryonix /etc/kryonix
cd /etc/kryonix
```

2. Analise a disponibilidade do flake antes de tentar qualquer instalação:

```sh
nix flake show --all-systems
nix flake check --keep-going
```

3. Se você possuir um host configurado (como o `inspiron` ou `glacier`), ative o perfil para este host. Para testes seguros, prefira sempre o `test` ou `boot` em vez de `switch`:

```sh
kryonix test
```

4. Para atualizar e aplicar as configurações de forma persistente (exigirá `sudo` caso aplique a configuração do NixOS no sistema hospedeiro):

```sh
kryonix switch
```

> [!WARNING]
> O Kryonix provê sua própria infraestrutura através da CLI e do host definitions. Nunca execute instalações destrutivas com scripts que usam `disko` em hosts instalados, e evite rodar ferramentas de instalação que podem particionar os discos (ex: `hosts/glacier/disks.nix`) num sistema hospedeiro rodando em produção.
