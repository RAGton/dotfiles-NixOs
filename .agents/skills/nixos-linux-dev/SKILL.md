---
name: nixos-linux-dev
description: Desenvolvimento de sistemas Linux com foco em NixOS — configuração declarativa, flakes, home-manager, derivações Nix, packaging, systemd, shell scripts, gerenciamento de pacotes e administração de sistemas. Use sempre que o usuário mencionar NixOS, nix flakes, configuration.nix, home.nix, derivações, overlays, nixpkgs, systemd units, shell scripting Linux, administração de sistemas ou qualquer tarefa de sysadmin/devops em ambiente Linux.
---

# NixOS & Linux Systems Dev

## Filosofia NixOS
- **Declarativo e reproduzível**: toda mudança vai em `.nix`, nunca `apt install` avulso
- **Flakes são o padrão moderno** — use `nix flake` em vez de `nix-env`
- **Home Manager** gerencia dotfiles e pacotes de usuário
- **Rollback** é sempre possível: `nixos-rebuild switch --rollback`

## Estrutura do kryonix (este repositório)

> Para implementar mudanças em host kryonix específico, use a skill **nix-host-implementation**.

```
/etc/kryonix/
├── flake.nix          # Entry point, inputs/outputs
├── flake/
│   ├── lib.nix        # mkNixosConfiguration, mkHomeConfiguration, overlays
│   ├── hosts.nix      # Mapeamento de hosts para configurações
│   ├── home.nix       # Mapeamento de user@host para homeConfigurations
│   └── packages.nix   # Pacotes próprios (kryonix-cli, kora, lightrag...)
├── hosts/
│   ├── glacier/default.nix   # Workstation principal (AMD + NVIDIA)
│   ├── inspiron/default.nix  # Laptop (rocha)
│   └── inspiron-nina/        # Laptop (nina)
├── profiles/          # Conjuntos de módulos (gamer, dev, laptop, server)
├── features/          # Funcionalidades opcionais (ai, gaming, virtualization)
├── modules/           # Módulos NixOS e home-manager
│   ├── nixos/
│   └── home-manager/
└── overlays/          # Patches e overrides de nixpkgs
```

## Estrutura genérica de projeto NixOS (referência externa)

```
/etc/nixos/
├── flake.nix
├── configuration.nix
├── hardware-configuration.nix
└── modules/
```

## Flake mínimo funcional

```nix
{
  description = "NixOS config";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, home-manager, ... }: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
      ];
    };
  };
}
```

## Comandos essenciais

```bash
# Rebuild e aplica
sudo nixos-rebuild switch --flake .#hostname

# Teste sem aplicar (boot only)
sudo nixos-rebuild test --flake .#hostname

# Atualiza inputs
nix flake update

# Busca pacote
nix search nixpkgs firefox

# Shell temporário com pacote
nix shell nixpkgs#ripgrep

# Dev shell para projeto
nix develop

# Garbage collect
sudo nix-collect-garbage -d
nix store gc
```

## Padrões comuns

### Adicionar serviço systemd customizado
```nix
systemd.services.meu-servico = {
  description = "Meu serviço";
  wantedBy = [ "multi-user.target" ];
  after = [ "network.target" ];
  serviceConfig = {
    ExecStart = "${pkgs.python3}/bin/python3 /opt/app/main.py";
    Restart = "on-failure";
    User = "nobody";
  };
};
```

### Overlay para customizar pacote
```nix
nixpkgs.overlays = [(final: prev: {
  meu-pkg = prev.meu-pkg.overrideAttrs (old: {
    patches = old.patches ++ [ ./fix.patch ];
  });
})];
```

### Home Manager — shell e dotfiles
```nix
programs.zsh = {
  enable = true;
  enableAutosuggestions = true;
  oh-my-zsh = { enable = true; theme = "robbyrussell"; };
};
programs.git = {
  enable = true;
  userName = "Seu Nome";
  userEmail = "seu@email.com";
};
```

## Shell scripting Linux — boas práticas
```bash
#!/usr/bin/env bash
set -euo pipefail  # Sempre: exit on error, undefined vars, pipe failures
IFS=$'\n\t'        # Separador seguro

# Verificar dependências
command -v jq >/dev/null || { echo "jq necessário"; exit 1; }

# Trap para cleanup
trap 'rm -f /tmp/arquivo_temp' EXIT
```

## Referências adicionais
- **Derivações customizadas**: ver [references/nix-derivations.md](references/nix-derivations.md)
- **Módulos NixOS avançados**: ver [references/nixos-modules.md](references/nixos-modules.md)
- **Troubleshooting**: ver [references/troubleshooting.md](references/troubleshooting.md)
