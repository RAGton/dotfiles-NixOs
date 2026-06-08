# Kryonix Shell — Arquitetura

O Kryonix Shell é a experiência de desktop própria do Kryonix. Existe em dois
sabores arquiteturais complementares, selecionáveis por host:

| Sabor | Spec | Base | Skill |
|---|---|---|---|
| **Kryonix Shell WM** | 07 | Hyprland puro | `phase7-kryonix-shell` |
| **Kryonix Aurora Shell** | 08 | KDE Plasma 6 | `phase8-kryonix-aurora` |

Ambos compartilham o mesmo daemon Rust (`kryonix-shell-daemon`), o mesmo modelo de
persistência (Spec 06 híbrida) e a mesma paleta de design.

---

## Stack compartilhada

### Daemon Rust — `kryonix-shell-daemon`

Evolução de `packages/kryonix-bar/` (D-Bus `org.kryonix.Bar` existente).

```
kryonix-shell-daemon
├── metrics.rs    — sysinfo: CPU/core, RAM, swap, GPU, rede, bateria, temperatura
├── hyprland.rs   — IPC socket2 (eventos: workspace, activewindow, openwindow)
├── kde.rs        — KWin/Plasma DBus (se environment=kde)
├── config.rs     — lê/escreve ~/.config/kryonix-shell/settings.toml + inotify
├── home_manager.rs — gera kryonix-shell.generated.nix no downstream
└── api.rs        — Axum 127.0.0.1 (GET /status /metrics /theme; POST /theme /save)
```

Feature flags no Cargo.toml:
- `hyprland-ipc` (ativo quando env=hyprland)
- `kde-dbus` (ativo quando env=kde)

API somente em `127.0.0.1` — sem socket externo.

### Persistência híbrida

Modelo idêntico à Spec 06 (Caelestia Hybrid):

```
UI edita settings
      ↓
~/.config/kryonix-shell/settings.toml  (mutável, hot-reload via inotify < 1s)
      ↓ kryonix shell save / kryonix aurora save
~/kryonixos/kryonix-shell/settings.toml  (commitado no downstream)
      ↓ + gera kryonix-shell.generated.nix
      ↓ home.file via mkOutOfStoreSymlink
Declarativo + vivo preservados
```

Fluxo de salvar na UI:
1. **Salvar** → aplica ao shell instantaneamente (TOML + inotify).
2. **Exportar HM** → gera `.generated.nix` + commit no downstream.
3. **Aplicar HM** → `kryonix home` (botão separado, com confirmação).

### Paleta de design (não alterar sem aprovação)

```
background:  #0B0F14 / #050A10 (Aurora)
surface:     #111827 / #0B1220 (Aurora)
surfaceAlt:  #1E293B
accent:      #38BDF8
accentStrong:#0EA5E9
text:        #E5E7EB
muted:       #94A3B8
border:      #1E3A5F
panel-alpha: 0.72–0.78
blur:        false (regra explícita)
```

---

## Sabor 1 — Kryonix Shell WM (Hyprland)

Ativo quando `kryonix.desktop.environment = "hyprland"` e `kryonix.desktop.shell = "kryonix"`.

```
Hyprland (compositor)
├── kryonix-shell-daemon [hyprland-ipc feature]
│   └── escuta .socket2.sock; emite eventos ao QML via API
│
├── kryonix-shell-ui (Quickshell + QML)
│   ├── Bar.qml       — top bar (workspaces, CPU/core, RAM, clock, tray)
│   ├── Launcher.qml  — Super+Space
│   ├── ControlCenter.qml — Super+A (Wi-Fi, áudio, Tailscale, brilho)
│   ├── Settings.qml  — Super+S
│   └── components/   — widgets reutilizáveis
│
└── sddm-kryonix-theme (QML; fallback Breeze obrigatório)
```

Atalhos núcleo:

| Atalho | Ação |
|---|---|
| Super+Enter | Terminal |
| Super+Space | Launcher |
| Super+A | Action Center |
| Super+S | Settings |
| Super+Tab | Workspace Overview |
| Super+H/J/K/L | Foco |
| Super+Shift+H/J/K/L | Mover janela |
| Super+1..9 | Workspace |
| Super+Shift+1..9 | Mover para workspace |
| Super+P | Power menu |
| Super+R | Reload shell |
| Super+B | Toggle bar |

Bar (direita → esquerda): `clock · tray · audio · net · GPU% · RAM% · CPU/core`

CPU por núcleo: `CPU ▃▅█▂▁▆▃▂ 39%` (mini barras UTF-8; update 500ms–1s).

---

## Sabor 2 — Kryonix Aurora Shell (KDE Plasma 6)

Ativo quando `kryonix.desktop.environment = "kde"` e `kryonix.aurora.enable = true`.

```
KDE Plasma 6 + KWin/Wayland
├── kryonix-shell-daemon [kde-dbus feature]
│
├── Kryonix Bar (Plasmoid QML ou Quickshell standalone)
│   └── CPU/core, RAM, GPU, rede, tray, clock — consome API 127.0.0.1
│
├── plasma-manager (HM)
│   ├── colorschemes, atalhos, widgets, KRunner
│   └── window-rules: transparência por classe (terminal, Dolphin, launcher)
│
├── kryonix-control-center (Kirigami)
│   ├── Aparência, Bar, Atalhos, Perfis
│   └── preview runtime + export HM + apply
│
└── sddm-kryonix-theme (QML; fallback Breeze obrigatório)
```

Transparência por app (nunca global):

| App | Opacidade |
|---|---|
| Terminal (Konsole) | 84% |
| Dolphin | 92% |
| Launcher | 86% |
| Painel | 78% |
| Settings | 90% |
| Browser / IDE | 100% (opaco) |

Perfis disponíveis: `minimal · productive · developer · gaming · client`.

---

## Integração com o ecossistema Kryonix

- **Brain**: command palette (`Super+X`) pode consultar `kryonix-brain` via `127.0.0.1`
  com confirmação antes de executar. Off-by-default. (Fase 7G / futuro)
- **CLI kryonix**: subcomandos `kryonix shell save` e `kryonix aurora save` seguem o
  mesmo padrão de `kryonix caelestia save` (Spec 06).
- **Cachix**: `kryonix-shell-daemon` e `kryonix-control-center` devem estar no cache
  antes do primeiro switch no Inspiron (coordenar com Fase 3).
- **SDDM**: único tema para ambos os sabores (`sddm-kryonix-theme`).

---

## Coexistência e defaults

```nix
# Padrão seguro — comportamento atual não muda
kryonix.desktop.environment = "kde";   # ou "hyprland"
kryonix.desktop.shell       = "caelestia";  # default Hyprland
kryonix.aurora.enable       = false;        # default KDE
kryonix.aurora.sddm.theme   = "breeze";     # fallback seguro
```

Para ativar o Kryonix Shell WM:
```nix
kryonix.desktop.shell = "kryonix";
```

Para ativar o Aurora Shell:
```nix
kryonix.aurora.enable  = true;
kryonix.aurora.profile = "productive";
```

Nunca ativar os dois na mesma sessão — `assertion` impede.

---

## Onde mexer

| Componente | Caminho |
|---|---|
| Opções | `lib/options.nix` |
| NixOS KDE | `modules/nixos/desktop/kde/` |
| NixOS Hyprland | `modules/nixos/desktop/hyprland/` (system) |
| HM KDE | `desktop/kde/` |
| HM Hyprland | `desktop/hyprland/` |
| Daemon Rust | `packages/kryonix-shell-daemon/` |
| UI QML (WM) | `packages/kryonix-shell-ui/` |
| Control Center | `packages/kryonix-control-center/` |
| SDDM | `packages/sddm-kryonix-theme/` |
| CLI bridge | `packages/kryonix-cli/lib/shell.sh` / `aurora.sh` |
| Perfis | `profiles/aurora/` |
| Gerado HM | `home/<user>/generated/kryonix-shell.generated.nix` |

## Segurança

- API daemon: somente `127.0.0.1`.
- `settings.toml` e `.generated.nix` nunca contêm secrets (whitelist no gerador).
- SDDM: fallback Breeze obrigatório + assertion no módulo.
- `plasma-manager overrideConfig = false` por default.
- Secrets permanecem em `/etc/kryonix/brain.env` (gitignored, runtime only).
