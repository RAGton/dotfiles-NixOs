# Hyprland Rice - DankMaterialShell (DMS)

Rice baseada em Material Design para Hyprland.

## 📦 O Que É

**DankMaterialShell (DMS)** é uma rice completa para Hyprland com:
- Design Material moderno
- Waybar customizado
- Rofi launcher
- Dunst notifications
- GTK/Qt theming

**Source**: https://github.com/AvengeMedia/DankMaterialShell

## 🎯 Status

⚠️ **EM DESENVOLVIMENTO** - Módulo criado, aguardando inspeção do repo DMS

### TODO

1. **Inspecionar estrutura do repo DMS**
   ```bash
   # Clonar temporariamente para ver estrutura
   git clone https://github.com/AvengeMedia/DankMaterialShell /tmp/dms
   ls -la /tmp/dms
   ```

2. **Ajustar paths no módulo `dms.nix`**
   - Waybar config path
   - Rofi config path
   - Hyprland config path
   - Wallpapers path

3. **Testar em host de desenvolvimento**
   ```nix
   # home/rocha/inspiron/default.nix
   imports = [
     ../../../desktop/hyprland/rice/dms.nix
   ];
   
   kryonix.rice.dms.enable = true;
   ```

4. **Validar compatibilidade**
   - Testar se configs do DMS funcionam com versão atual do Hyprland
   - Verificar dependências (fonts, pacotes)
   - Ajustar se necessário

## 📋 Como Usar (Quando Completo)

### 1. Habilitar no Home Manager

```nix
# home/rocha/<hostname>/default.nix
{
  imports = [
    ../../../desktop/hyprland/rice/dms.nix
  ];

  # Habilitar DMS
  kryonix.rice.dms = {
    enable = true;
    variant = "default";  # ou "minimal" ou "full"
    wallpaper = ./path/to/wallpaper.png;  # opcional
  };
}
```

### 2. Escolher Hyprland no Sistema

```nix
# hosts/<hostname>/default.nix
kryonix.desktop.environment = "hyprland";
```

### 3. Rebuild

```bash
nixos-rebuild switch --flake .#<hostname>
home-manager switch --flake .#rag@<hostname>
```

## 🏗️ Arquitetura

```
desktop/hyprland/rice/
├── README.md          # Este arquivo
└── dms.nix            # Módulo DMS
    ├── options
    ├── xdg.configFile (links)
    ├── packages
    ├── services (waybar, dunst)
    └── theming (gtk, qt)
```

## 🎨 Variantes

### default
Configuração padrão do DMS com todos os widgets principais.

### minimal
Menos widgets, foco em performance. Bom para hardware mais fraco.

### full
Todos os widgets e features. Requer hardware decente.

## 📦 Dependências

Instaladas automaticamente pelo módulo:
- waybar
- dunst
- material-design-icons
- material-symbols
- grim/slurp
- networkmanagerapplet
- bibata-cursors

## 🔧 Customização

### Wallpaper

```nix
kryonix.rice.dms.wallpaper = ./wallpapers/meu-wallpaper.png;
```

### Modificar Waybar

Após aplicar, você pode sobrescrever:
```nix
xdg.configFile."waybar/config".text = ''
  # Seu config customizado
'';
```

## ⚠️ Conflitos

DMS pode conflitar com:
- Configs manuais em `~/.config/hypr/`
- Configs manuais em `~/.config/waybar/`
- Outras rices de Hyprland

**Solução**: Remova configs manuais antes de habilitar DMS.

## 🚀 Próximos Passos

1. [ ] Inspecionar repo DMS
2. [ ] Ajustar paths dos configs
3. [ ] Testar em inspiron
4. [ ] Documentar variantes
5. [ ] Screenshots

## 📚 Recursos

- [DankMaterialShell Repo](https://github.com/AvengeMedia/DankMaterialShell)
- [Hyprland Docs](https://wiki.hyprland.org/)
- [Waybar Wiki](https://github.com/Alexays/Waybar/wiki)
