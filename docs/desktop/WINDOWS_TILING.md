# Desktop: Tiling no Windows

Padronização **opcional** do fluxo de janelas em mosaico do Kryonix no Windows,
espelhando o tiling do KDE/Hyprland no Linux. São apenas arquivos de referência
— **não afetam o build NixOS** e nada é aplicado automaticamente no Windows.

Os configs versionados ficam em [`windows/`](../../windows/README.md).

## Opções

| Critério             | FancyZones (PowerToys) | Komorebi              | GlazeWM         |
| -------------------- | ---------------------- | --------------------- | --------------- |
| Tipo                 | Zonas fixas (snap)     | Tiling dinâmico (BSP) | Tiling dinâmico |
| Config               | GUI                    | JSON                  | YAML            |
| Hotkeys              | PowerToys              | `whkd` (separado)     | Embutido        |
| CLI                  | Não                    | Forte (`komorebic`)   | Básica          |
| Curva de aprendizado | Baixa                  | Alta                  | Média           |
| Melhor para          | Começar rápido         | Usuário técnico       | Migrar do i3    |

**Recomendação:** GlazeWM para começar; Komorebi para controle total via CLI.

## Instalação

### Komorebi (+ whkd)

```powershell
winget install LGUG2Z.komorebi LGUG2Z.whkd
# copie windows/komorebi/komorebi.json → %USERPROFILE%\.config\komorebi\komorebi.json
# copie windows/komorebi/whkdrc        → %USERPROFILE%\.config\whkdrc
komorebic start --whkd
```

### GlazeWM

```powershell
winget install glzr-io.glazewm
# copie windows/glazewm/config.yaml → %USERPROFILE%\.glzr\glazewm\config.yaml
```

### FancyZones

Parte do PowerToys (`winget install Microsoft.PowerToys`). Config via GUI; sem
arquivo versionado. Use zonas de grade + snap `Win+Shift+setas`.

## Mapa de teclas (cross-OS)

No Windows, `Win+letra` é reservado pelo SO, então usamos `Alt`. A lógica vim
**HJKL** é idêntica ao KDE (`desktop/kde/keybinds.nix`) e ao Hyprland.

| Ação                 | Linux (KDE/Hyprland)     | Windows (Komorebi/GlazeWM) |
| -------------------- | ------------------------ | -------------------------- |
| Foco                 | `Meta + H/J/K/L`         | `Alt + H/J/K/L`            |
| Mover janela         | `Meta + Shift + H/J/K/L` | `Alt + Shift + H/J/K/L`    |
| Redimensionar        | `Meta + Ctrl + H/J/K/L`  | `Alt + Ctrl + H/J/K/L`     |
| Ir p/ workspace N    | `Meta + 1..9`            | `Alt + 1..5`               |
| Mover p/ workspace N | `Meta + Shift + 1..9`    | `Alt + Shift + 1..5`       |
| Toggle floating      | `Meta + Shift + F`       | `Alt + Shift + Space`      |

## Cores

Bordas nos tokens Kryonix: foco `#38BDF8`, inativo `#334155` — coerente com o
color-scheme `kryonix-dark` (ver [PLASMA_THEME_KRYONIX_DARK.md](PLASMA_THEME_KRYONIX_DARK.md)).
