# Kryonix — Tiling no Windows

Configs **opcionais e versionáveis** para reproduzir, no Windows, o fluxo de
janelas em mosaico (tiling) do Kryonix no Linux (KDE Plasma + Krohnkite /
Hyprland). Não fazem parte do build NixOS — são apenas arquivos de referência.

> Nenhum binário é versionado e nada altera o Windows automaticamente. Você
> instala e aplica manualmente.

## Comparação rápida

| Critério            | FancyZones (PowerToys) | Komorebi              | GlazeWM            |
| ------------------- | ---------------------- | --------------------- | ------------------ |
| Tipo                | Zonas fixas (snap)     | Tiling dinâmico (BSP) | Tiling dinâmico    |
| Estilo              | Manual / arrastar      | i3/yabai-like         | i3-like            |
| Config              | GUI                    | JSON                  | YAML               |
| Hotkeys             | PowerToys              | `whkd` (separado)     | Embutido           |
| Curva de aprendizado| Baixa                  | Alta                  | Média              |
| CLI                 | Não                    | Forte (`komorebic`)   | `glazewm` básica   |
| Melhor para         | Começar rápido         | Usuário técnico       | Migrar do i3       |

**Recomendação Kryonix:** GlazeWM para começar (config única, hotkeys
embutidas); Komorebi para quem quer controle total via CLI.

## Arquivos

```txt
windows/
├── komorebi/
│   ├── komorebi.json   → %USERPROFILE%\.config\komorebi\komorebi.json
│   └── whkdrc          → %USERPROFILE%\.config\whkdrc
├── glazewm/
│   └── config.yaml     → %USERPROFILE%\.glzr\glazewm\config.yaml
└── README.md
```

## Instalação

### Komorebi (+ whkd)

```powershell
winget install LGUG2Z.komorebi
winget install LGUG2Z.whkd
# copie komorebi.json e whkdrc para os caminhos acima, então:
komorebic start --whkd
```

### GlazeWM

```powershell
winget install glzr-io.glazewm
# copie config.yaml para %USERPROFILE%\.glzr\glazewm\config.yaml e inicie o GlazeWM
```

### FancyZones

Faz parte do **Microsoft PowerToys** (`winget install Microsoft.PowerToys`).
Configuração é via GUI; não há arquivo versionado aqui — use zonas de coluna/grade
e o snap com `Win+Shift+setas`.

## Mapa de teclas (cross-OS)

O modificador muda entre plataformas (no Windows, `Win+letra` é reservado pelo SO,
então usamos `Alt`). A lógica vim **HJKL** é a mesma do KDE
(`desktop/kde/keybinds.nix`) e do Hyprland.

| Ação                  | Linux (KDE/Hyprland)      | Windows (Komorebi/GlazeWM) |
| --------------------- | ------------------------- | -------------------------- |
| Foco                  | `Meta + H/J/K/L`          | `Alt + H/J/K/L`            |
| Mover janela          | `Meta + Shift + H/J/K/L`  | `Alt + Shift + H/J/K/L`    |
| Redimensionar         | `Meta + Ctrl + H/J/K/L`   | `Alt + Ctrl + H/J/K/L`     |
| Ir p/ workspace N     | `Meta + 1..9`             | `Alt + 1..5`               |
| Mover p/ workspace N  | `Meta + Shift + 1..9`     | `Alt + Shift + 1..5`       |
| Toggle floating       | `Meta + Shift + F`        | `Alt + Shift + Space`      |
| Fullscreen / monocle  | `Meta + F` / `Meta + M`   | `Alt + F`                  |

## Cores

As bordas usam os tokens da identidade Kryonix:

- foco/accent: `#38BDF8`
- inativo/border: `#334155`

Ver também `docs/desktop/WINDOWS_TILING.md`.
