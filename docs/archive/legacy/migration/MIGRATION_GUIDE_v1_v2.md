# 🗺️ MIGRATION GUIDE - RagOS v1 → v2

**Guia Prático de Migração**  
**Autor**: AI Maintainer  
**Data**: 2026-02-18

---

## 📋 PRÉ-REQUISITOS

Antes de iniciar a migração:

```bash
# 1. Backup da configuração atual
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
cp -r /home/rocha/GitHub/node-nixos /home/rocha/GitHub/node-nixos.backup

# 2. Commit do estado atual
cd /home/rocha/GitHub/node-nixos
git add -A
git commit -m "checkpoint: pre-migration snapshot"
git tag pre-migration-v1

# 3. Verificar que sistema atual funciona
nix flake check
sudo nixos-rebuild dry-build --flake .#inspiron
```

✅ **Só continue se todos os comandos acima passarem sem erros**

---

## 🎯 SPRINT 1: SISTEMA DE OPÇÕES

**Objetivo**: Criar infraestrutura de opções `rag.*`  
**Tempo**: 2-3 horas  
**Risco**: ⚠️ BAIXO

### Passo 1.1: Criar Lib Directory

```bash
mkdir -p lib
```

### Passo 1.2: Criar lib/default.nix

```nix
# lib/default.nix
{ lib, ... }:
{
  # Helper para criar módulos NixOS
  mkNixosModule = path: { config, lib, pkgs, ... }: {
    imports = [ path ];
  };

  # Helper para criar módulos Home Manager  
  mkHomeModule = path: { config, lib, pkgs, ... }: {
    imports = [ path ];
  };
}
```

### Passo 1.3: Criar lib/options.nix

```nix
# lib/options.nix
{ config, lib, pkgs, ... }:

{
  options.rag = {
    desktop = {
      environment = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "kde" "hyprland" "gnome" "dms" ]);
        default = null;
        description = ''
          Desktop environment to use.
          - "kde": KDE Plasma 6
          - "hyprland": Hyprland (vanilla)
          - "dms": DankMaterialShell (Hyprland + rice)
          - "gnome": GNOME (future)
          - null: Headless (no DE)
        '';
      };

      wayland = lib.mkOption {
        type = lib.types.bool;
        default = config.rag.desktop.environment != null;
        description = "Enable Wayland support";
      };
    };

    features = {
      gaming = {
        enable = lib.mkEnableOption "Gaming stack (Steam, Lutris, gamemode)";
        
        steam = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = config.rag.features.gaming.enable;
            description = "Install Steam";
          };
        };

        lutris = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = config.rag.features.gaming.enable;
            description = "Install Lutris";
          };
        };
      };

      virtualization = {
        enable = lib.mkEnableOption "KVM/QEMU virtualization";
      };

      development = {
        rust = {
          enable = lib.mkEnableOption "Rust development environment";
        };

        python = {
          enable = lib.mkEnableOption "Python development environment";
        };

        go = {
          enable = lib.mkEnableOption "Go development environment";
        };

        kubernetes = {
          enable = lib.mkEnableOption "Kubernetes tools (kubectl, k9s, etc)";
        };
      };

      networking = {
        tailscale = {
          enable = lib.mkEnableOption "Tailscale VPN";
        };
      };
    };

    branding = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "RagOS";
        description = "System branding name";
      };

      logo = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to branding logo";
      };
    };
  };

  config = {
    # Assertions para validar configuração
    assertions = [
      {
        assertion = config.rag.desktop.environment != null -> 
          (config.services.xserver.enable or false || 
           config.programs.hyprland.enable or false);
        message = "Desktop environment requires display server";
      }
    ];
  };
}
```

### Passo 1.4: Criar desktop/manager.nix

```nix
# desktop/manager.nix
# Auto-import do desktop baseado em rag.desktop.environment
{ config, lib, ... }:

{
  imports = 
    lib.optional (config.rag.desktop.environment == "kde")
      ./kde/system.nix
    ++
    lib.optional (config.rag.desktop.environment == "hyprland")
      ./hyprland/system.nix
    ++
    lib.optional (config.rag.desktop.environment == "dms")
      ./hyprland/system.nix  # DMS usa Hyprland como base
    ++
    lib.optional (config.rag.desktop.environment == "gnome")
      ./gnome/system.nix;
}
```

### Passo 1.5: Atualizar flake.nix

```nix
# flake.nix
# Adicionar import do lib/options em mkNixosConfiguration

mkNixosConfiguration =
  hostname: username:
  nixpkgs.lib.nixosSystem {
    specialArgs = {
      inherit inputs outputs hostname;
      isDarwin = false;
      userConfig = users.${username};
      nixosModules = "${self}/modules/nixos";
    };
    modules = [
      ./hosts/${hostname}
      ./lib/options.nix        # ✨ NOVO
      ./desktop/manager.nix    # ✨ NOVO
    ];
  };
```

### Passo 1.6: Testar

```bash
# Validar sintaxe
nix flake check

# Tentar build (não aplica ainda)
nixos-rebuild dry-build --flake .#inspiron

# Se tudo OK, commit
git add lib/ desktop/manager.nix flake.nix
git commit -m "feat: add rag.* options system (Sprint 1)"
```

✅ **Sprint 1 completo se `nix flake check` passar**

---

## 🎨 SPRINT 2: REFATORAR DESKTOP

**Objetivo**: Separar system vs user configs dos DEs  
**Tempo**: 1-2 horas  
**Risco**: ⚠️ MÉDIO

### Passo 2.1: Refatorar KDE

```bash
# Renomear arquivo atual
mv modules/nixos/desktop/kde/default.nix desktop/kde/system.nix

# Criar user config
```

```nix
# desktop/kde/user.nix
{ config, lib, inputs, ... }:

{
  imports = [ inputs.plasma-manager.homeManagerModules.plasma-manager ];

  # Mover configs do plasma-manager de modules/home-manager/desktop/kde
  # para cá (copiar conteúdo)
}
```

### Passo 2.2: Refatorar Hyprland

```bash
# Renomear
mv modules/nixos/desktop/hyprland/default.nix desktop/hyprland/system.nix
```

```nix
# desktop/hyprland/system.nix
# Atualizar portal:
{ pkgs, ... }:
{
  services.displayManager.gdm.enable = true;
  services.xserver.updateDbusEnvironment = true;

  programs.hyprland = {
    enable = true;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;  # ✅ ATUALIZADO
    withUWSM = true;
  };

  # ... resto do arquivo
}
```

```nix
# desktop/hyprland/user.nix
{ config, lib, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    
    settings = {
      # Configs básicos do Hyprland
      # (mover de modules/home-manager/desktop/hyprland se existir)
    };
  };
}
```

### Passo 2.3: Atualizar Hosts para Usar Opções

```nix
# hosts/inspiron/default.nix
# ANTES:
imports = [
  # ...
  "${nixosModules}/desktop/kde"  # ❌ REMOVER
];

# DEPOIS:
{
  imports = [
    # ... hardware e outros
    # NÃO importar desktop diretamente
  ];

  rag.desktop.environment = "kde";  # ✅ ADICIONAR
  
  # ... resto
}
```

Fazer o mesmo para `hosts/inspiron/default.nix`.

### Passo 2.4: Atualizar Home Manager

```nix
# home/rocha/inspiron/default.nix
# ANTES:
imports = [
  "${nhModules}/common"
  "${nhModules}/desktop/kde"  # ❌ REMOVER
];

# DEPOIS:
{
  imports = [
    "${nhModules}/common"
    # Desktop user config importado via rice/manager (futuro)
    # Por enquanto, importar manualmente:
  ];

  # Se desktop == kde, importar user config
  # (Será automatizado no Sprint 3)
}
```

### Passo 2.5: Testar Rebuild

```bash
# Dry run
sudo nixos-rebuild dry-build --flake .#inspiron

# Se OK, aplicar de verdade
sudo nixos-rebuild switch --flake .#inspiron

# Verificar que KDE/Hyprland ainda funciona
# Reboot recomendado

# Commit
git add desktop/ hosts/ home/
git commit -m "feat: refactor desktop to system/user split (Sprint 2)"
```

✅ **Sprint 2 completo se sistema bootar normalmente**

---

## 🎨 SPRINT 3: IMPLEMENTAR DMS

**Objetivo**: Adicionar DankMaterialShell como rice  
**Tempo**: 2-4 horas  
**Risco**: ⚠️ ALTO

### Passo 3.1: Adicionar Flake Input

```nix
# flake.nix
inputs = {
  # ... outros inputs

  # DankMaterialShell
  dms = {
    url = "github:AvengeMedia/DankMaterialShell";
    flake = false;
  };
};
```

```bash
# Atualizar lock
nix flake lock
```

### Passo 3.2: Criar Módulo DMS

```bash
mkdir -p rice/dms
```

```nix
# rice/dms/default.nix
{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.rag.rice.dms;
  dmsSource = inputs.dms;
in
{
  options.rag.rice.dms = {
    enable = lib.mkEnableOption "DankMaterialShell rice";

    theme = lib.mkOption {
      type = lib.types.enum [ "dark" "light" ];
      default = "dark";
      description = "DMS color theme";
    };

    userConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Additional Hyprland config to append";
    };
  };

  config = lib.mkIf cfg.enable {
    # DMS requer Hyprland
    assertions = [{
      assertion = config.wayland.windowManager.hyprland.enable or false;
      message = "DMS requires Hyprland to be enabled";
    }];

    # Dependências do DMS
    home.packages = with pkgs; [
      waybar
      rofi-wayland
      dunst
      swww  # wallpaper daemon
      # Adicionar outras dependências conforme necessário
    ];

    # Waybar
    programs.waybar = {
      enable = true;
      systemd.enable = true;
    };

    # Link configs do DMS
    xdg.configFile = {
      # Hyprland DMS config
      "hypr/dms.conf".source = "${dmsSource}/hypr/hyprland.conf";  # Ajustar path

      # Waybar
      "waybar/dms" = {
        source = "${dmsSource}/waybar";
        recursive = true;
      };

      # Rofi
      "rofi/dms" = {
        source = "${dmsSource}/rofi";
        recursive = true;
      };

      # Override principal do Hyprland para source DMS
      "hypr/hyprland.conf".text = ''
        # DankMaterialShell
        source = ~/.config/hypr/dms.conf

        # User overrides
        ${cfg.userConfig}
      '';
    };

    # Habilitar Hyprland no Home Manager
    wayland.windowManager.hyprland = {
      enable = true;
      xwayland.enable = true;
    };
  };
}
```

**⚠️ NOTA**: O path exato dentro de `${dmsSource}` depende da estrutura do repo DMS. Ajustar após inspecionar:

```bash
nix flake prefetch github:AvengeMedia/DankMaterialShell
# Ou clone manual para inspecionar estrutura
```

### Passo 3.3: Criar Rice Manager (Auto-import)

```nix
# rice/manager.nix
{ config, lib, ... }:

{
  imports = 
    lib.optional (config.rag.rice or null == "dms")
      ./dms/default.nix
    ++
    lib.optional (config.rag.rice or null == "catppuccin")
      ./catppuccin/default.nix;
}
```

### Passo 3.4: Adicionar Opção rag.rice

```nix
# lib/options.nix (adicionar dentro de options.rag)

rice = lib.mkOption {
  type = lib.types.nullOr (lib.types.enum [ "dms" "catppuccin" "bart" ]);
  default = null;
  description = ''
    User theming/ricing to apply.
    - "dms": DankMaterialShell (Hyprland + Material Design)
    - "catppuccin": Catppuccin theme
    - "bart": Bart theme
    - null: No theming
  '';
};
```

**⚠️ ATENÇÃO**: Esta opção é para **Home Manager**, não NixOS. Precisamos criar um `lib/home-options.nix` separado ou adicionar no módulo do rice.

**Alternativa Simples**: Definir opção diretamente no módulo:

```nix
# rice/dms/default.nix
options.rag.rice = lib.mkOption {
  type = lib.types.nullOr lib.types.str;
  default = null;
  description = "Rice theme to apply";
};

# E no config:
config = lib.mkIf (cfg.rice == "dms") {
  # ... configs
};
```

### Passo 3.5: Habilitar DMS no Host

```nix
# Sistema: Hyprland base
# hosts/inspiron/default.nix
rag.desktop.environment = "hyprland";  # ou "dms" se quiser
```

```nix
# User: DMS rice
# home/rocha/inspiron/default.nix
{
  imports = [
    "${nhModules}/common"
    ../../rice/dms  # Import manual por enquanto
  ];

  rag.rice.dms.enable = true;  # Ativar DMS
}
```

### Passo 3.6: Testar DMS

```bash
# Rebuild home manager
home-manager switch --flake .#rocha@inspiron

# Verificar que configs foram linkados
ls -la ~/.config/hypr/dms.conf
ls -la ~/.config/waybar/dms/

# Logout e login novamente (selecionar Hyprland no GDM)

# Se Hyprland crashar, voltar para geração anterior:
home-manager generations
home-manager switch --switch-generation <N>

# Commit se funcionar
git add rice/ lib/options.nix flake.nix home/
git commit -m "feat: implement DankMaterialShell rice (Sprint 3)"
```

✅ **Sprint 3 completo se DMS carregar sem crashes**

---

## 📦 SPRINT 4: FEATURES MODULARES

**Objetivo**: Mover features para módulos opcionais  
**Tempo**: 2-3 horas  
**Risco**: ⚠️ BAIXO

### Passo 4.1: Criar Features Directory

```bash
mkdir -p features/{gaming,virtualization,development,networking}
```

### Passo 4.2: Feature Gaming

```nix
# features/gaming/default.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.rag.features.gaming;
in
{
  config = lib.mkIf cfg.enable {
    programs.steam.enable = cfg.steam.enable;
    
    environment.systemPackages = lib.optionals cfg.lutris.enable [
      pkgs.lutris
    ] ++ [
      pkgs.gamemode
      # Outras ferramentas de gaming
    ];

    # Performance tweaks
    programs.gamemode.enable = true;
  };
}
```

### Passo 4.3: Feature Virtualization

```nix
# features/virtualization/default.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.rag.features.virtualization;
in
{
  config = lib.mkIf cfg.enable {
    # Mover conteúdo de modules/virtualization/kvm.nix para cá
    virtualisation.libvirtd.enable = true;
    programs.virt-manager.enable = true;
    
    users.users.${config.userConfig.name}.extraGroups = [ "libvirtd" ];
  };
}
```

### Passo 4.4: Importar Features

```nix
# flake.nix (dentro de mkNixosConfiguration)
modules = [
  ./hosts/${hostname}
  ./lib/options.nix
  ./desktop/manager.nix
  ./features/gaming        # ✨ NOVO
  ./features/virtualization  # ✨ NOVO
  # ... outras features
];
```

### Passo 4.5: Atualizar Hosts

```nix
# hosts/inspiron/default.nix
# ANTES:
imports = [
  ../../modules/kernel/zen.nix
  ../../modules/virtualization/kvm.nix
  # ...
];

# DEPOIS:
{
  rag.features = {
    gaming.enable = true;
    virtualization.enable = true;
  };
}
```

### Passo 4.6: Testar

```bash
nixos-rebuild dry-build --flake .#inspiron
sudo nixos-rebuild switch --flake .#inspiron

git add features/ hosts/ flake.nix
git commit -m "feat: modularize features (Sprint 4)"
```

✅ **Sprint 4 completo se features funcionam normalmente**

---

## 🎁 SPRINT 5: PROFILES

**Objetivo**: Criar presets composáveis  
**Tempo**: 1 hora  
**Risco**: ⚠️ MUITO BAIXO

### Passo 5.1: Criar Profiles

```nix
# profiles/desktop.nix
{
  imports = [
    ../features/gaming
    ../features/virtualization
    ../modules/kernel/zen.nix  # Ainda em modules/ por enquanto
  ];

  rag.features = {
    gaming.enable = true;
    virtualization.enable = true;
  };
}
```

```nix
# profiles/laptop.nix
{
  imports = [
    ../modules/services/tlp  # Power management
  ];

  services.tlp.enable = true;
  powerManagement.cpuFreqGovernor = "powersave";
}
```

### Passo 5.2: Usar nos Hosts

```nix
# hosts/inspiron/default.nix
{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/desktop.nix  # ✨ Profile
  ];

  rag.desktop.environment = "hyprland";
  
  # Overrides específicos do host
  networking.hostName = "inspiron";
}
```

### Passo 5.3: Testar e Commit

```bash
nixos-rebuild dry-build --flake .#inspiron
sudo nixos-rebuild switch --flake .#inspiron

git add profiles/ hosts/
git commit -m "feat: add composable profiles (Sprint 5)"
```

✅ **Sprint 5 completo**

---

## 👤 SPRINT 6: CORE/USERS

**Objetivo**: Refatorar user configs  
**Tempo**: 2 horas  
**Risco**: ⚠️ MUITO BAIXO

### Passo 6.1: Criar Users Directory

```bash
mkdir -p users/rocha
```

```nix
# users/rocha/core.nix
# Mover configs compartilhados de home/rocha/*/default.nix
{ config, lib, pkgs, nhModules, ... }:

{
  imports = [
    "${nhModules}/common"
    "${nhModules}/programs/git"
    "${nhModules}/programs/zsh"
    # ... outros compartilhados
  ];

  programs.git = {
    userName = "rag";
    userEmail = "g.rocha@estudante.ifmt.edu.br";
  };

  # Configs compartilhados
}
```

```nix
# users/rocha/inspiron.nix
{ config, lib, pkgs, ... }:

{
  imports = [ ./core.nix ];

  # Host-specific configs
  rag.rice.dms.enable = true;

  home.packages = with pkgs; [
    # Gaming stuff
  ];
}
```

### Passo 6.2: Atualizar flake.nix

```nix
# flake.nix
mkHomeConfiguration =
  system: username: hostname:
  home-manager.lib.homeManagerConfiguration {
    # ...
    modules = [
      ./users/${username}/${hostname}.nix  # ✅ NOVO PATH
      ./rice/manager.nix
    ];
  };
```

### Passo 6.3: Testar e Commit

```bash
home-manager build --flake .#rocha@inspiron
home-manager switch --flake .#rocha@inspiron

git add users/ flake.nix
git commit -m "feat: refactor user configs to users/ (Sprint 6)"
```

✅ **Sprint 6 completo**

---

## 🎉 MIGRAÇÃO COMPLETA

### Validação Final

```bash
# 1. Flake check
nix flake check

# 2. Build todos os hosts
nixos-rebuild dry-build --flake .#inspiron
nixos-rebuild dry-build --flake .#inspiron

# 3. Build todos os users
home-manager build --flake .#rocha@inspiron
home-manager build --flake .#rocha@inspiron

# 4. Aplicar
sudo nixos-rebuild switch --flake .#inspiron
home-manager switch --flake .#rocha@inspiron
```

### Tag da Release

```bash
git tag v2.0.0-migrated
git push origin v2.0.0-migrated
```

---

## 🔄 ROLLBACK

Se algo der errado:

```bash
# Sistema
sudo nixos-rebuild switch --rollback

# Home Manager
home-manager generations
home-manager switch --switch-generation <N>

# Código
git reset --hard pre-migration-v1
```

---

## 📊 MÉTRICAS PÓS-MIGRAÇÃO

Compare antes/depois:

### Adicionar Novo Host

**Antes**: ~50 linhas  
**Depois**: ~15 linhas  
**Melhoria**: 70% redução

### Trocar Desktop

**Antes**: 2 arquivos, 4 linhas  
**Depois**: 1 arquivo, 1 linha  
**Melhoria**: 75% redução

### Build Time

```bash
time nixos-rebuild build --flake .#inspiron
```

(não deve mudar significativamente)

---

## ✅ CHECKLIST FINAL

- [ ] Todos os sprints executados
- [ ] Sistema boota normalmente
- [ ] KDE funciona
- [ ] Hyprland funciona
- [ ] DMS funciona
- [ ] `nix flake check` passa
- [ ] Documentação atualizada
- [ ] Tag criada
- [ ] Backup mantido

---

**Migração concluída! 🚀**

---

## 📚 PRÓXIMOS PASSOS

Após migração:

1. **Deprecar `modules/` antigo**
   - Adicionar avisos de deprecation
   - Planejar remoção (2 releases)

2. **Adicionar Novos Desktops**
   - GNOME
   - Sway
   - i3

3. **Adicionar Novas Rices**
   - Catppuccin
   - Bart

4. **Documentar Customização**
   - Como criar nova feature
   - Como criar novo profile
   - Como criar nova rice

---

**Guia de migração finalizado.**
