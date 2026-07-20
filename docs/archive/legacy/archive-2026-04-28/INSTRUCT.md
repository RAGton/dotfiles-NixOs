# INSTRUCT.MD - RagOS NixOS Configuration

**Projeto**: RagOS - Distribuição pessoal baseada em NixOS  
**Mantenedor**: rag  
**Objetivo**: Sistema NixOS modular, declarativo e fácil de evoluir por IAs

---

## 1. ARQUITETURA DO REPOSITÓRIO

### Princípios Fundamentais

1. **Flake-First**: `flake.nix` é a única fonte de verdade
2. **Modularidade Estrita**: Separação por responsabilidade, não por host
3. **Composability**: Profiles + Features + Desktop + Rice
4. **Declarativo até o Fim**: Zero configuração manual pós-install
5. **Portabilidade**: Funciona em qualquer hardware com minimal changes

### Estrutura Atual (v1 - Em Migração)

```
node-nixos/
├── flake.nix              # Source of truth
├── hosts/                 # APENAS hardware + escolhas de alto nível
├── modules/               # Sistema base (nixos/ darwin/ home-manager/)
├── home/                  # User configs (Home Manager entry points)
├── files/                 # Assets (wallpapers, avatars, etc)
└── overlays/              # Package overrides
```

### Estrutura Alvo (v2 - Roadmap)

```
node-nixos/
├── core/                  # Sistema base (nixos.nix, darwin.nix, shared.nix)
├── profiles/              # Presets (laptop, desktop, vm, server)
├── features/              # Features modulares (gaming, dev, networking)
├── desktop/               # Desktop environments (kde/, hyprland/, gnome/)
│   ├── <DE>/system.nix   # NixOS module
│   └── <DE>/user.nix     # Home Manager module
├── rice/                  # User theming/ricing (dms/, catppuccin/)
├── users/                 # User configs (rag/core.nix, rag/inspiron.nix)
├── hosts/                 # APENAS hardware-configuration.nix + opções
└── lib/                   # Helper functions (mkSystem, mkHome, options)
```

---

## 2. REGRAS OBRIGATÓRIAS

### ❌ NUNCA FAÇA ISSO

1. **Nunca hardcode desktop no host**
   ```nix
   # ❌ ERRADO
   imports = [ ../../modules/desktop/kde ];
   ```

2. **Nunca misture system e user concerns**
   ```nix
   # ❌ ERRADO (wallpaper no sistema)
   environment.systemPackages = [ wallpaper-engine ];
   ```

3. **Nunca use imports diretos para features**
   ```nix
   # ❌ ERRADO
   imports = [ ../../features/gaming ];
   ```

4. **Nunca copie dotfiles manualmente**
   ```nix
   # ❌ ERRADO
   home.file.".config/hypr/hyprland.conf".text = '' ... '';
   ```

5. **Nunca quebre a avaliação do Nix**
   - Sempre teste com `nix flake check` antes de commit
   - Use `lib.mkIf` para código condicional
   - Declare assertions para dependências

### ✅ SEMPRE FAÇA ISSO

1. **Use sistema de opções**
   ```nix
   # ✅ CORRETO
   rag.desktop.environment = "hyprland";
   rag.features.gaming.enable = true;
   ```

2. **Separe system vs user**
   ```nix
   # ✅ System (NixOS)
   programs.hyprland.enable = true;
   
   # ✅ User (Home Manager)
   wayland.windowManager.hyprland.settings = { ... };
   ```

3. **Use flake inputs para dotfiles externos**
   ```nix
   # ✅ CORRETO
   inputs.dms = {
     url = "github:AvengeMedia/DankMaterialShell";
     flake = false;
   };
   ```

4. **Documente cada módulo**
   ```nix
   # Sempre inclua cabeçalho:
   # O que é
   # Por quê
   # Como
   # Riscos
   ```

---

## 3. COMO ADICIONAR NOVOS COMPONENTES

### 3.1 Adicionar Novo Host

1. **Criar diretório**:
   ```bash
   mkdir -p hosts/novo-host
   ```

2. **Gerar hardware-configuration.nix**:
   ```bash
   nixos-generate-config --root /mnt --show-hardware-config > hosts/novo-host/hardware-configuration.nix
   ```

3. **Criar default.nix minimal**:
   ```nix
   # hosts/novo-host/default.nix
   {
     imports = [
       ./hardware-configuration.nix
       ../../profiles/desktop.nix  # ou laptop/vm/server
     ];

     rag = {
       desktop.environment = "kde";  # ou hyprland/gnome
       features = {
         gaming.enable = true;
         virtualization.enable = false;
       };
     };

     networking.hostName = "novo-host";
     system.stateVersion = "26.05";
   }
   ```

4. **Registrar no flake.nix**:
   ```nix
   nixosConfigurations.novo-host = mkNixosConfiguration "novo-host" "rag";
   ```

5. **Criar user config**:
   ```nix
   # users/rocha/novo-host.nix
   {
     imports = [ ./core.nix ];
     rag.rice = "dms";
   }
   ```

6. **Registrar home config**:
   ```nix
   homeConfigurations."rag@novo-host" = mkHomeConfiguration "x86_64-linux" "rag" "novo-host";
   ```

### 3.2 Adicionar Nova Feature

1. **Criar módulo**:
   ```nix
   # features/nova-feature/default.nix
   { config, lib, pkgs, ... }:
   
   let
     cfg = config.rag.features.nova-feature;
   in
   {
     options.rag.features.nova-feature = {
       enable = lib.mkEnableOption "Nova feature";
       
       opcao = lib.mkOption {
         type = lib.types.str;
         default = "valor";
         description = "Descrição da opção";
       };
     };

     config = lib.mkIf cfg.enable {
       environment.systemPackages = [ pkgs.pacote ];
       # ... resto da config
     };
   }
   ```

2. **Importar em lib/options.nix** (v2) ou **nixos/common** (v1):
   ```nix
   imports = [ ../../features/nova-feature ];
   ```

3. **Usar no host**:
   ```nix
   rag.features.nova-feature.enable = true;
   ```

### 3.3 Adicionar Novo Desktop

1. **Criar system module**:
   ```nix
   # desktop/novo-de/system.nix
   { config, lib, pkgs, ... }:
   {
     services.xserver.enable = true;
     services.xserver.desktopManager.novo-de.enable = true;
     # ... display manager, etc
   }
   ```

2. **Criar user module**:
   ```nix
   # desktop/novo-de/user.nix
   { config, lib, pkgs, ... }:
   {
     # Configs do Home Manager
     xdg.configFile."novo-de/config".text = '' ... '';
   }
   ```

3. **Criar desktop manager** (auto-import):
   ```nix
   # desktop/manager.nix
   { config, lib, ... }:
   {
     imports = lib.optional (config.rag.desktop.environment == "novo-de")
       ./novo-de/system.nix;
   }
   ```

4. **Usar no host**:
   ```nix
   rag.desktop.environment = "novo-de";
   ```

### 3.5 Adicionar Tema Desktop-Specific

⚠️ **IMPORTANTE**: Temas são específicos do desktop environment!

**Temas KDE Plasma** vão em: `desktop/kde/themes/`  
**Temas Hyprland** vão em: `desktop/hyprland/themes/`

#### Exemplo: Tema KDE

```nix
# desktop/kde/themes/meu-tema/default.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.rag.theme.meu-tema;
in
{
  options.rag.theme.meu-tema = {
    enable = lib.mkEnableOption "Tema Meu-Tema (KDE Plasma ONLY)";
    # ... opções de configuração
  };

  config = lib.mkIf cfg.enable {
    # ⚠️ Usa componentes exclusivos do KDE:
    # - plasma-manager (programs.plasma)
    # - Kvantum (Qt theming engine)
    # - Aurorae (window decorations)
    
    programs.plasma = {
      workspace.lookAndFeel = "MeuTema";
      # ...
    };
  };
}
```

**Não funciona em**: Hyprland, GNOME, Xfce, i3/Sway

### 3.4 Adicionar Nova Rice

1. **Adicionar como flake input** (se externo):
   ```nix
   # flake.nix
   inputs.nova-rice = {
     url = "github:usuario/repo";
     flake = false;
   };
   ```

2. **Criar módulo**:
   ```nix
   # rice/nova-rice/default.nix
   { config, lib, pkgs, inputs, ... }:
   
   let
     cfg = config.rag.rice.nova-rice;
     source = inputs.nova-rice;
   in
   {
     options.rag.rice.nova-rice.enable = lib.mkEnableOption "Nova rice";

     config = lib.mkIf cfg.enable {
       xdg.configFile = {
         "waybar/nova-rice".source = "${source}/waybar";
         # ... link outros configs
       };

       home.packages = [ /* deps */ ];
     };
   }
   ```

3. **Importar em users/rocha/core.nix**:
   ```nix
   imports = [ ../../rice/nova-rice ];
   ```

4. **Ativar no user config**:
   ```nix
   # users/rocha/inspiron.nix
   rag.rice.nova-rice.enable = true;
   ```

---

## 4. PADRÕES DE NOMENCLATURA

### Opções Customizadas

```nix
rag.{categoria}.{subcategoria}.{opção}

Exemplos:
rag.desktop.environment = "kde";
rag.features.gaming.enable = true;
rag.rice.dms.theme = "dark";
rag.branding.name = "RagOS";
```

### Arquivos

- **Módulos NixOS**: `features/gaming/default.nix`
- **Módulos Home Manager**: `rice/dms/default.nix`
- **Hosts**: `hosts/<hostname>/default.nix`
- **Users**: `users/<username>/<hostname>.nix`
- **Profiles**: `profiles/<tipo>.nix`

### Imports

```nix
# ✅ Use paths relativos claros
../../features/gaming

# ✅ Ou use specialArgs
"${nixosModules}/features/gaming"

# ❌ Evite imports mágicos
<nixpkgs/...>
```

---

## 5. POLÍTICA DE IMPORTS

### System-Level (NixOS)

**O que pode ser importado**:
- `core/nixos.nix`
- `profiles/*.nix`
- `features/*/default.nix`
- `desktop/*/system.nix`

**O que NÃO pode**:
- ❌ Módulos de `rice/`
- ❌ User-specific configs
- ❌ Home Manager modules

### User-Level (Home Manager)

**O que pode ser importado**:
- `users/<user>/core.nix`
- `desktop/*/user.nix`
- `rice/*/default.nix`
- `modules/home-manager/*` (legacy)

**O que NÃO pode**:
- ❌ System-level features (gaming, virtualization)
- ❌ Kernel modules
- ❌ NixOS services

---

## 6. POLÍTICA DE OPÇÕES

### Definir Opções

```nix
# Sempre em um módulo separado
# lib/options.nix (v2) ou inline no módulo (v1)

options.rag.features.gaming = {
  enable = lib.mkEnableOption "Gaming stack";
  
  steam.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Install Steam";
  };
};
```

### Usar Opções

```nix
# Host config
rag.features.gaming.enable = true;

# Módulo implementation
config = lib.mkIf config.rag.features.gaming.enable {
  programs.steam.enable = config.rag.features.gaming.steam.enable;
};
```

### Hierarquia de Opções

```
rag.
├── desktop.
│   ├── environment (kde|hyprland|gnome)
│   └── wayland (bool)
├── features.
│   ├── gaming.enable
│   ├── development.{rust,python,go}.enable
│   ├── virtualization.enable
│   └── networking.{tailscale,vpn}.enable
├── rice.
│   ├── theme (dms|catppuccin|bart)
│   └── dms.{enable, theme, userConfig}
└── branding.
    ├── name
    └── logo
```

---

## 7. POLÍTICA DE HOME MANAGER

### Separação de Responsabilidades

| Categoria | System (NixOS) | User (Home Manager) |
|-----------|----------------|---------------------|
| **Desktop WM/DE** | Hyprland package, portals | hyprland.conf, keybinds |
| **Gaming** | Steam, drivers | Per-user game configs |
| **Development** | Compilers, runtimes | LSPs, editor configs |
| **Theming** | System fonts | GTK/Qt themes, cursors |

### Estrutura User Config

```nix
# users/rocha/core.nix - Compartilhado entre hosts
{
  programs.git = { ... };
  programs.zsh = { ... };
  programs.neovim = { ... };
}

# users/rocha/inspiron.nix - Específico do host
{
  imports = [ ./core.nix ];
  
  rag.rice = "dms";
  programs.vscode.enable = true;
  home.packages = [ /* gaming */ ];
}
```

### Home Manager Modules

**Onde colocar**:
- Programs: `modules/home-manager/programs/<name>/`
- Services: `modules/home-manager/services/<name>/`
- Desktop user configs: `desktop/<DE>/user.nix`
- Ricing: `rice/<theme>/default.nix`

**Template**:
```nix
# modules/home-manager/programs/exemplo/default.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.exemplo;
in
{
  options.programs.exemplo = {
    enable = lib.mkEnableOption "Exemplo program";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.exemplo ];
    xdg.configFile."exemplo/config".text = '' ... '';
  };
}
```

---

## 8. COMO NÃO QUEBRAR AVALIAÇÃO DO NIX

### Checklist Pré-Commit

```bash
# 1. Verificar sintaxe
nix flake check

# 2. Build dry-run
nixos-rebuild dry-build --flake .#hostname

# 3. Avaliar outputs
nix flake show

# 4. Verificar formatting (se usar)
nixpkgs-fmt --check .
```

### Erros Comuns

#### Erro: "infinite recursion"

**Causa**: Referência circular entre módulos

**Solução**:
```nix
# ❌ ERRADO
config.rag.desktop = config.rag.features.gaming.desktop;

# ✅ CORRETO
config.rag.desktop = "kde";  # valor direto
```

#### Erro: "attribute X missing"

**Causa**: Opção não definida ou módulo não importado

**Solução**:
```nix
# Definir opção:
options.rag.feature.enable = lib.mkEnableOption "...";

# Ou importar módulo que define:
imports = [ ./path/to/module ];
```

#### Erro: "value is a function while a set was expected"

**Causa**: Esqueceu de chamar função ou passou argumentos errados

**Solução**:
```nix
# ❌ ERRADO
imports = [ (import ./module.nix) ];

# ✅ CORRETO
imports = [ ./module.nix ];
```

### Uso de Assertions

```nix
config = lib.mkIf cfg.enable {
  assertions = [
    {
      assertion = config.programs.hyprland.enable;
      message = "DMS requires Hyprland";
    }
    {
      assertion = cfg.theme == "dark" || cfg.theme == "light";
      message = "Invalid theme: ${cfg.theme}";
    }
  ];
};
```

---

## 9. WORKFLOWS COMUNS

### Atualizar Sistema

```bash
# Update flake inputs
nix flake update

# Rebuild system
sudo nixos-rebuild switch --flake .#inspiron

# Rebuild user
home-manager switch --flake .#rocha@inspiron
```

### Testar Mudanças Sem Aplicar

```bash
# Dry run (mostra o que mudaria)
nixos-rebuild dry-build --flake .#inspiron

# Build sem ativar
nixos-rebuild build --flake .#inspiron
```

### Rollback

```bash
# Listar gerações
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Voltar para geração anterior
sudo nixos-rebuild switch --rollback

# Home Manager rollback
home-manager generations
home-manager switch --switch-generation <N>
```

### Limpar Store

```bash
# Garbage collect
nix-collect-garbage -d

# System profile specific
sudo nix-collect-garbage -d

# Otimizar (deduplicar)
nix-store --optimise
```

---

## 10. TROUBLESHOOTING PARA IAs

### "Não sei onde colocar essa config"

**Checklist**:
1. É específico de hardware? → `hosts/<host>/`
2. É uma feature reusável? → `features/<name>/`
3. É preset de features? → `profiles/<type>.nix`
4. É desktop environment? → `desktop/<DE>/system.nix`
5. É user theming? → `rice/<theme>/` ou `desktop/<DE>/user.nix`
6. É user program? → `modules/home-manager/programs/`

### "Quero trocar de KDE para Hyprland"

```nix
# ANTES (v1 - manual)
# hosts/inspiron/default.nix
imports = [ ../../modules/desktop/kde ];  # Remover linha

# DEPOIS (v2 - via opção)
rag.desktop.environment = "hyprland";  # Mudar string
```

### "Quero adicionar DMS"

```nix
# 1. Flake input
inputs.dms = {
  url = "github:AvengeMedia/DankMaterialShell";
  flake = false;
};

# 2. Criar módulo rice/dms/default.nix (ver seção 3.4)

# 3. Habilitar no user
# users/rocha/inspiron.nix
rag.rice = "dms";
```

### "Config não está aplicando"

**Debug**:
```bash
# 1. Verificar se opção está definida
nix repl
:l <nixpkgs>
:l .
:p nixosConfigurations.inspiron.config.rag.features.gaming.enable

# 2. Verificar se módulo está importado
nix eval .#nixosConfigurations.inspiron.options.rag.features.gaming

# 3. Ver diff antes de aplicar
nixos-rebuild dry-activate --flake .#inspiron
```

---

## 11. CONVENÇÕES DE CÓDIGO

### Formatação

```nix
# Indent: 2 espaços
# Chaves: estilo K&R
# Let bindings: antes de in

{ config, lib, pkgs, ... }:

let
  cfg = config.rag.feature;
  helper = x: x + 1;
in
{
  options = { ... };
  
  config = lib.mkIf cfg.enable {
    # ...
  };
}
```

### Comentários

```nix
# Cabeçalho de módulo (sempre incluir):
# ==============================================================================
# Módulo: <Nome>
# Autor: rag
#
# O que é:
# - Descrição breve do propósito
#
# Por quê:
# - Justificativa da existência
#
# Como:
# - Como funciona internamente
#
# Riscos:
# - Potenciais problemas/side effects
# ==============================================================================

# Comentários inline (quando necessário):
boot.kernelParams = [
  "split_lock_detect=off"  # Fix Hogwarts Legacy perf issue
];
```

### Ordem de Atributos

```nix
{
  # 1. Metadata
  description = "...";
  
  # 2. Imports
  imports = [ ... ];
  
  # 3. Options
  options = { ... };
  
  # 4. Config
  config = { ... };
}
```

---

## 12. INTEGRAÇÃO COM GITHUB COPILOT

### Como este arquivo funciona

Este `INSTRUCT.md` deve estar em:
- `.github/copilot-instructions.md` (legacy)
- `INSTRUCT.md` (raiz do repo)

### Uso pelo Copilot

Quando você fizer perguntas ao Copilot, ele vai:
1. Ler este arquivo automaticamente
2. Entender a arquitetura do projeto
3. Seguir as regras definidas aqui
4. Gerar código consistente com os padrões

### Dicas para IAs

```markdown
# Ao receber tarefa:
1. Ler INSTRUCT.md primeiro
2. Identificar categoria (feature/desktop/rice/host)
3. Verificar regras obrigatórias (seção 2)
4. Seguir template apropriado (seção 3)
5. Validar com `nix flake check`

# Ao propor mudanças:
1. Explicar o que vai mudar
2. Mostrar diff (antes/depois)
3. Listar riscos potenciais
4. Pedir confirmação antes de aplicar
```

---

## 13. ROADMAP DE MIGRAÇÃO (v1 → v2)

### Fase 1: Sistema de Opções ✅
- [ ] Criar `lib/options.nix`
- [ ] Definir `rag.desktop.environment`
- [ ] Definir `rag.features.*`
- [ ] Criar `desktop/manager.nix` (auto-import)

### Fase 2: Refatorar Desktop
- [ ] Separar `desktop/*/system.nix` e `desktop/*/user.nix`
- [ ] Migrar KDE
- [ ] Migrar Hyprland (atualizar portal)
- [ ] Criar desktop manager

### Fase 3: Implementar DMS
- [ ] Adicionar flake input
- [ ] Criar `rice/dms/default.nix`
- [ ] Testar integração
- [ ] Documentar customização

### Fase 4: Features Modulares
- [ ] Criar `features/gaming/`
- [ ] Criar `features/virtualization/`
- [ ] Criar `features/development/`
- [ ] Migrar de `modules/` para `features/`

### Fase 5: Profiles
- [ ] Criar `profiles/desktop.nix`
- [ ] Criar `profiles/laptop.nix`
- [ ] Criar `profiles/vm.nix`
- [ ] Refatorar hosts para usar profiles

### Fase 6: Core/Users
- [ ] Criar `core/{nixos,darwin,shared}.nix`
- [ ] Criar `users/rocha/core.nix`
- [ ] Migrar home configs

### Fase 7: Deprecate Old Structure
- [ ] Marcar `modules/` como deprecated
- [ ] Redirecionar imports
- [ ] Remover após 2 releases estáveis

---

## 14. REFERÊNCIAS EXTERNAS

### Repositórios Inspiração
- [Misterio77/nix-config](https://github.com/Misterio77/nix-config) - Modular architecture
- [fufexan/dotfiles](https://github.com/fufexan/dotfiles) - Hyprland setup
- [hlissner/dotfiles](https://github.com/hlissner/dotfiles) - Profiles system

### Documentação Oficial
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Pills](https://nixos.org/guides/nix-pills/)

### Comunidade
- [NixOS Discourse](https://discourse.nixos.org/)
- [r/NixOS](https://reddit.com/r/NixOS)
- [NixOS Wiki](https://nixos.wiki/)

---

## 15. CONCLUSÃO

Este arquivo é um **contrato vivo** entre você (mantenedor humano) e IAs futuras.

**Para IAs que lerem este arquivo**:
- Você agora entende a arquitetura completa do RagOS
- Você conhece as regras que não podem ser quebradas
- Você sabe onde colocar cada tipo de código
- Você pode evoluir o projeto sem quebrar nada

**Para o mantenedor humano**:
- Mantenha este arquivo atualizado
- Documente decisões de design aqui
- Use como checklist em PRs
- Confie que IAs vão seguir isso

**Última atualização**: 2026-02-18  
**Versão da arquitetura**: v1 (migrando para v2)

---

**rag out. 🚀**
