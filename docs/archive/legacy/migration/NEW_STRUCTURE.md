# 📁 NEW STRUCTURE - RagOS v2

**Este arquivo documenta a arquitetura v2 do RagOS**

---

## 🎯 PRINCÍPIOS DA ARQUITETURA v2

1. **Options Over Imports** - Escolhas via opções, não imports diretos
2. **Separation of Concerns** - Desktop ≠ Rice ≠ Features
3. **Composability** - Profiles + Features = Configuração completa
4. **DRY** - Zero duplicação entre hosts
5. **AI-Friendly** - Qualquer IA entende hierarquia de decisões

---

## 📂 ESTRUTURA DE DIRETÓRIOS

```
node-nixos/
│
├── core/                           # Sistema base (v2)
│   ├── nixos.nix                  # Config base NixOS
│   ├── darwin.nix                 # Config base Darwin
│   └── shared.nix                 # Compartilhado entre plataformas
│
├── lib/                            # Helpers e opções (v2)
│   ├── default.nix                # Helper functions
│   └── options.nix                # Definição de rag.* options
│
├── profiles/                       # Presets composáveis (v2)
│   ├── desktop.nix                # Gaming + Virtualization + Zen kernel
│   ├── laptop.nix                 # TLP + powersave
│   ├── vm.nix                     # Minimal + SSH
│   └── server.nix                 # Headless + services
│
├── features/                       # Features modulares (v2)
│   ├── gaming/
│   │   └── default.nix            # Steam, Lutris, gamemode
│   ├── virtualization/
│   │   └── default.nix            # KVM, virt-manager, libvirt
│   ├── development/
│   │   ├── default.nix
│   │   ├── rust.nix
│   │   ├── python.nix
│   │   ├── go.nix
│   │   └── kubernetes.nix
│   ├── networking/
│   │   ├── tailscale.nix
│   │   └── vpn.nix
│   └── branding/
│       └── node.nix
│
├── desktop/                        # Desktop Environments (v2 - refatorado)
│   ├── manager.nix                # Auto-import baseado em rag.desktop.environment
│   │
│   ├── kde/
│   │   ├── system.nix             # NixOS: SDDM, Plasma6, packages
│   │   └── user.nix               # Home Manager: plasma-manager config
│   │
│   ├── hyprland/
│   │   ├── system.nix             # NixOS: Hyprland, GDM, portals
│   │   └── user.nix               # Home Manager: hyprland.conf base
│   │
│   ├── gnome/
│   │   ├── system.nix             # (futuro)
│   │   └── user.nix               # (futuro)
│   │
│   └── common/
│       ├── wayland.nix            # Portals, env vars
│       └── xwayland.nix           # Compat layer
│
├── rice/                           # User Theming/Ricing (v2 - novo)
│   ├── manager.nix                # Auto-import baseado em rag.rice
│   │
│   ├── dms/                       # DankMaterialShell
│   │   ├── default.nix            # Home Manager module
│   │   ├── waybar.nix             # Waybar customizations
│   │   ├── rofi.nix               # Rofi config
│   │   ├── hyprland.nix           # Keybinds, animations
│   │   └── theme.nix              # Material colors
│   │
│   ├── catppuccin/
│   │   └── default.nix            # Catppuccin theme
│   │
│   └── bart/
│       └── default.nix            # Bart theme
│
├── users/                          # User Configurations (v2 - refatorado)
│   └── rag/
│       ├── core.nix               # Shared across all hosts
│       ├── inspiron.nix            # Host-specific (desktop)
│       └── inspiron.nix           # Host-specific (laptop)
│
├── hosts/                          # Hardware + Escolhas (v2 - simplificado)
│   ├── inspiron/
│   │   ├── default.nix            # APENAS: hardware + profile + opções
│   │   ├── hardware-configuration.nix
│   │   └── disks.nix
│   │
│   ├── inspiron/
│   │   ├── default.nix
│   │   ├── hardware-configuration.nix
│   │   └── disks.nix
│   │
│   └── iso/
│       └── default.nix
│
├── modules/                        # ⚠️ LEGACY (v1 - deprecated)
│   ├── nixos/                     # Migrar para features/
│   ├── darwin/                    # Migrar para core/
│   └── home-manager/              # Manter por enquanto
│
├── files/                          # Assets (inalterado)
│   ├── avatar/
│   ├── wallpaper/
│   └── screenshots/
│
├── overlays/                       # Package overrides (inalterado)
│   └── default.nix
│
├── flake.nix                       # Single source of truth (atualizado)
├── flake.lock                      # Lockfile
│
└── docs/                           # Documentação
    ├── INSTRUCT.md                # Manual para IAs
    ├── ARCHITECTURE_AUDIT.md      # Auditoria completa
    ├── MIGRATION_GUIDE.md         # Guia de migração
    ├── SUMMARY.md                 # Resumo executivo
    └── NEW_STRUCTURE.md           # Este arquivo
```

---

## 🔧 COMO FUNCIONA

### Sistema de Opções

```nix
# hosts/inspiron/default.nix
{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/desktop.nix
  ];

  rag = {
    # Desktop environment (system-level)
    desktop.environment = "hyprland";  # ou "kde" | "gnome" | "dms"

    # Features (opt-in)
    features = {
      gaming.enable = true;
      virtualization.enable = true;
      development = {
        rust.enable = true;
        kubernetes.enable = true;
      };
    };

    # Branding
    branding = {
      name = "RagOS";
      logo = ../../files/logo.png;
    };
  };
}
```

```nix
# users/rocha/inspiron.nix
{
  imports = [ ./core.nix ];

  # Rice (user-level theming)
  rag.rice.dms.enable = true;  # ou catppuccin, bart

  # Host-specific packages
  home.packages = [ /* ... */ ];
}
```

### Auto-Import Managers

#### Desktop Manager

```nix
# desktop/manager.nix
{ config, lib, ... }:
{
  imports = 
    lib.optional (config.rag.desktop.environment == "kde")
      ./kde/system.nix
    ++
    lib.optional (config.rag.desktop.environment == "hyprland")
      ./hyprland/system.nix;
}
```

**Como funciona**:
1. Host define `rag.desktop.environment = "kde"`
2. Desktop manager lê opção
3. Auto-importa `desktop/kde/system.nix`
4. Zero imports manuais no host

#### Rice Manager

```nix
# rice/manager.nix
{ config, lib, ... }:
{
  imports = 
    lib.optional (config.rag.rice.dms.enable or false)
      ./dms/default.nix;
}
```

**Como funciona**:
1. User config define `rag.rice.dms.enable = true`
2. Rice manager auto-importa `rice/dms/default.nix`
3. Configs linkados via `xdg.configFile`

---

## 🎨 SEPARAÇÃO: DESKTOP vs RICE

### Desktop (System-Level)

**O que é**: Window Manager / Desktop Environment + Display Manager + Portals

**Responsabilidades**:
- Instalar compositor (Hyprland, KWin)
- Configurar display manager (SDDM, GDM)
- Habilitar portals (screensharing, file picker)
- System packages necessários

**Onde**: `desktop/*/system.nix`

**Exemplo (Hyprland)**:
```nix
# desktop/hyprland/system.nix
{
  programs.hyprland.enable = true;
  services.displayManager.gdm.enable = true;
  # ... portals, etc
}
```

---

### Rice (User-Level)

**O que é**: Theming, aparência, keybinds, barras, launchers

**Responsabilidades**:
- Waybar/Polybar configs
- Rofi/Wofi themes
- Hyprland keybinds e animations
- GTK/Qt themes
- Wallpapers

**Onde**: `rice/*/default.nix`

**Exemplo (DMS)**:
```nix
# rice/dms/default.nix
{
  xdg.configFile."waybar/config".source = ...;
  xdg.configFile."rofi/config.rasi".source = ...;
  xdg.configFile."hypr/keybinds.conf".source = ...;
}
```

---

## 📦 PROFILES vs FEATURES

### Profiles (Presets)

**O que é**: Combinação pré-definida de features para tipo de máquina

**Exemplo**:
```nix
# profiles/desktop.nix
{
  imports = [
    ../features/gaming
    ../features/virtualization
  ];

  rag.features = {
    gaming.enable = true;
    virtualization.enable = true;
  };
}
```

**Quando usar**: Você tem um tipo de máquina comum (desktop, laptop, VM)

---

### Features (Módulos Independentes)

**O que é**: Funcionalidade isolada e reutilizável

**Exemplo**:
```nix
# features/gaming/default.nix
{ config, lib, pkgs, ... }:
{
  config = lib.mkIf config.rag.features.gaming.enable {
    programs.steam.enable = true;
    environment.systemPackages = [ pkgs.lutris ];
  };
}
```

**Quando usar**: Você quer opt-in para funcionalidade específica

---

## 🔀 FLUXO DE CONFIGURAÇÃO

### Build de um Host (inspiron)

```
flake.nix
  ↓ mkNixosConfiguration "inspiron"
  ↓ modules = [
  │   hosts/inspiron/default.nix
  │   lib/options.nix              ← Define rag.* options
  │   desktop/manager.nix          ← Auto-import desktop
  │   profiles/desktop.nix         ← Importa features
  │   features/gaming              ← Gaming stack
  │   features/virtualization      ← KVM stack
  │ ]
  ↓
NixOS System (inspiron)
```

### Build de um User (rocha@inspiron)

```
flake.nix
  ↓ mkHomeConfiguration "rag" "inspiron"
  ↓ modules = [
  │   users/rocha/inspiron.nix
  │   users/rocha/core.nix           ← Shared configs
  │   rice/manager.nix             ← Auto-import rice
  │   rice/dms/default.nix         ← DMS configs
  │ ]
  ↓
Home Manager (rocha@inspiron)
```

---

## 🎯 EXEMPLOS DE USO

### Adicionar Novo Host (Laptop)

```nix
# hosts/laptop/default.nix
{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/laptop.nix      # TLP, powersave
  ];

  rag = {
    desktop.environment = "hyprland";
    features = {
      development.rust.enable = true;
    };
  };

  networking.hostName = "laptop";
}
```

**Linhas de código**: ~15  
**Features habilitadas**: TLP, Hyprland, Rust dev

---

### Trocar Desktop (KDE → Hyprland)

```diff
# hosts/inspiron/default.nix
- rag.desktop.environment = "kde";
+ rag.desktop.environment = "hyprland";
```

**Rebuild**:
```bash
sudo nixos-rebuild switch --flake .#inspiron
```

**Alterações**: 1 linha

---

### Adicionar Nova Feature

```nix
# features/docker/default.nix
{ config, lib, pkgs, ... }:
{
  config = lib.mkIf config.rag.features.docker.enable {
    virtualisation.docker.enable = true;
    users.users.${config.userConfig.name}.extraGroups = [ "docker" ];
  };
}
```

```nix
# lib/options.nix (adicionar)
options.rag.features.docker.enable = lib.mkEnableOption "Docker";
```

```nix
# hosts/inspiron/default.nix (usar)
rag.features.docker.enable = true;
```

---

### Trocar Rice (DMS → Catppuccin)

```diff
# users/rocha/inspiron.nix
- rag.rice.dms.enable = true;
+ rag.rice.catppuccin.enable = true;
```

```bash
home-manager switch --flake .#rocha@inspiron
```

---

## 🔍 TROUBLESHOOTING

### Opção não existe

**Erro**:
```
error: The option `rag.features.gaming.enable' does not exist
```

**Solução**:
1. Verificar que `lib/options.nix` define a opção
2. Verificar que `lib/options.nix` está importado no flake
3. Rebuild com `--show-trace` para ver stack

---

### Desktop não carrega

**Debug**:
```bash
# Ver qual módulo foi importado
nix eval .#nixosConfigurations.inspiron.config.rag.desktop.environment

# Ver se desktop manager importou corretamente
nix eval .#nixosConfigurations.inspiron.config.programs.hyprland.enable
```

**Solução**:
- Verificar que `desktop/manager.nix` tem lógica correta
- Verificar que `desktop/hyprland/system.nix` existe

---

### Rice não aplica

**Debug**:
```bash
# Ver configs linkados
ls -la ~/.config/hypr/
ls -la ~/.config/waybar/

# Ver qual rice está ativo
nix eval .#homeConfigurations."rocha@inspiron".config.rag.rice.dms.enable
```

**Solução**:
- Verificar que `rice/manager.nix` importa módulo
- Verificar que paths no `xdg.configFile` estão corretos

---

## 📊 COMPARAÇÃO v1 vs v2

| Aspecto | v1 (Legacy) | v2 (Nova) |
|---------|-------------|-----------|
| **Desktop** | Import direto | Opção + auto-import |
| **Features** | Import direto | Opção booleana |
| **Rice** | Misturado com desktop | Separado (rice/) |
| **Hosts** | 50+ linhas | 15 linhas |
| **Trocar DE** | Editar 2 arquivos | Mudar 1 string |
| **Adicionar host** | Copy-paste | Profile + opções |
| **IA-friendly** | ⚠️ Médio | ✅ Alto |

---

## 🚀 PRÓXIMOS PASSOS

Após implementação completa da v2:

1. **Deprecar `modules/`**
   - Adicionar warnings
   - Migrar código restante
   - Remover após 2 releases

2. **Adicionar Desktops**
   - GNOME
   - Sway
   - i3/Bspwm

3. **Adicionar Rices**
   - Catppuccin complete
   - Bart integration

4. **Tooling**
   - CLI para criar host/feature/rice
   - Templates (nix flake init)
   - CI/CD validation

---

## 📚 DOCUMENTAÇÃO

- **INSTRUCT.md** - Manual completo para IAs
- **ARCHITECTURE_AUDIT.md** - Auditoria e problemas
- **MIGRATION_GUIDE.md** - Passo a passo da migração
- **SUMMARY.md** - Resumo executivo
- **NEW_STRUCTURE.md** - Este arquivo

---

## ✅ VALIDAÇÃO

Após implementar v2, verificar:

```bash
# 1. Flake check
nix flake check

# 2. Build todos os outputs
nix flake show
nix build .#nixosConfigurations.inspiron.config.system.build.toplevel
nix build .#homeConfigurations."rocha@inspiron".activationPackage

# 3. Métricas
# - Linhas em hosts/inspiron/default.nix: < 20
# - Trocar desktop: 1 linha mudada
# - Adicionar feature: opção booleana
```

---

**Estrutura v2 documentada. Ready to implement! 🚀**
