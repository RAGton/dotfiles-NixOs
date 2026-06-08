# Kryonix Aurora Shell — UX e Design

Documentação de UX, design e decisões visuais do **Kryonix Aurora Shell**,
o sabor do Kryonix Shell baseado em KDE Plasma 6.

Para arquitetura técnica: `KRYONIX_SHELL_ARCHITECTURE.md`.
Para roadmap: `KRYONIX_SHELL_ROADMAP.md`.
Para spec técnica: `specs/08-kryonix-aurora-shell.md`.

---

## Filosofia

```
KDE é o motor.
Kryonix vira a experiência.
Home Manager vira a memória declarativa.
Rust vira o backend rápido.
Qt/QML vira a interface fluida.
```

O Aurora Shell não substitui o KDE — ele **doma o KDE**. O objetivo é:
- Experiência visual própria e coerente.
- Transparência elegante sem blur pesado.
- Configuração permanente via UI que vira declarativa via HM.
- Atalhos de teclado como workflow de trabalho real.
- Perfis por tarefa: dev, focus, gaming, cliente.

---

## Identidade visual

### Paleta Aurora

```
background:   #050A10   (quase preto)
surface:      #0B1220
surfaceAlt:   #111827
panel:        rgba(8, 13, 22, 0.78)
accent:       #38BDF8   (azul Kryonix)
accentStrong: #0EA5E9
text:         #E5E7EB
muted:        #94A3B8
border:       #1E3A5F   (azul escuro sutil)
danger:       #F43F5E
warning:      #F59E0B
success:      #22C55E
```

### Princípios visuais

1. **Sem blur pesado** — regra explícita. Transparência limpa, sem efeito fosco.
2. **Alto contraste** — texto `#E5E7EB` sobre fundo escuro; muted `#94A3B8` para secundários.
3. **Borda azul sutil** — 1px `rgba(56, 189, 248, 0.35)` em containers flutuantes.
4. **Animações curtas** — < 200ms; sem efeitos que cansam.
5. **Pouco ruído** — ícones apenas onde necessário; texto como fallback.
6. **Radius moderado** — 14px nos containers; 8px em elementos menores.

---

## Kryonix Bar — Design Premium

### Conceito visual

Bar flutuante, pill-shaped, arredondada. **Não** cola nas bordas da tela — fica
"suspensa" com 4–6px de margem. Inspiração: ilha flutuante com vidro escuro.

```
        ╭──────────────────────────────────────────────────────────────────────────────────────╮
        │  ╭───╮╭───╮   firefox — Kryonix Shell Architecture    10:42    ╭──────╮  ╭───────╮  │
        │  │ 1 ││ 2 │                                           08/06    │CPU ▅▇│  │▓▓▓░ 61│  │
        │  ╰───╯╰───╯   [actmon]                                         │▂▃▅▇▅▃│  │RAM    │  │
        ╰──────────────────────────────────────────────────────────────────────────────────────╯
```

Layout em 4 zonas separadas com gap (não uma barra contínua cheia):

```
╭─[Workspaces]─╮   ╭─[Window Title]────────────────────────╮   ╭─[Clock]─╮   ╭─[Metrics]──╮  ╭─[Tray]─╮
│ ╭─╮╭─╮╭─╮   │   │  firefox — Kryonix Shell Architecture  │   │  10:42  │   │CPU ▂▅█▃▂   │  │⚡ 🔊 ≡ │
│ │1││2││3│   │   │                                        │   │  08/06  │   │RAM ███░ 61%│  │       │
│ ╰─╯╰─╯╰─╯   │   │                                        │   │         │   │GPU ██░  28%│  │       │
╰──────────────╯   ╰────────────────────────────────────────╯   ╰─────────╯   ╰────────────╯  ╰────────╯
```

### Mockup detalhado

```
 ┄┄┄┄ 6px margin topo ┄┄┄┄

╭─────────────────────────────────────────────────────────────────────────────────────────╮
│  ╭──╮╭──╮╭──╮  │  firefox — Kryonix Shell Documentation    │  10:42  │  ▂▅█▃ 39%  🔊  │
│  │ 1││ 2││ 3│  │                                            │  08/06  │  ███░  61% ≡  │
│  ╰──╯╰──╯╰──╯  │                                            │         │  ██░   28% ↑↓ │
╰─────────────────────────────────────────────────────────────────────────────────────────╯

 ┄┄┄┄ 6px margin ┄┄┄┄┄ [desktop wallpaper] ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
```

### Especificação visual

| Propriedade | Valor |
|---|---|
| Background | `rgba(8, 13, 22, 0.82)` |
| Border | `1px solid rgba(56, 189, 248, 0.25)` |
| Border radius | `16px` (pill geral) |
| Box shadow | `0 4px 24px rgba(0,0,0,0.45)` |
| Padding | `0 16px` |
| Altura | `38px` |
| Margem do topo | `6px` |
| Margem lateral | `8px` |
| Separadores | `1px rgba(255,255,255,0.08)` |
| Fonte | `JetBrains Mono 10.5px` |

### Zona 1 — Workspaces (esquerda)

Workspace ativo: pill accent `rgba(56, 189, 248, 0.20)` + borda accent + texto branco.
Workspaces com janela aberta: pill `rgba(255,255,255,0.08)` + texto `#94A3B8`.
Workspaces vazios: apenas número em `#475569` (discreto, não poluem).

```
╭──╮  ╭──╮  ╭──╮  ╭──╮  ╭──╮
│ 1│  │ 2│  │ 3│  │ 4│  │ 5│
╰──╯  ╰──╯  ╰──╯  ╰──╯  ╰──╯
 ▲ ativo   ▲ com   ▲ com   ▲ vazio
 accent    janela  janela
```

Ao passar o mouse: tooltip com nome do workspace (ex: `2: web`).

### Zona 2 — Título da janela ativa (centro-esquerdo)

- Ícone da app 16x16 + nome da app + título truncado em 50 chars.
- Cor `#CBD5E1`; separador `›` em `#475569`.
- Clique → lista de janelas do workspace.

```
 firefox  ›  Kryonix Shell Documentation — Firefox
```

### Zona 3 — Clock (centro-direito)

Hora em destaque (`#E5E7EB`, 13px bold), data menor (`#94A3B8`, 10px).
Alinhado verticalmente. Clique → calendário popup.

```
  10:42
  08/06
```

### Zona 4 — Métricas (direita) ← principal upgrade

Cada métrica é um **mini card** com label + barra visual + percentual.
Cards empilhados verticalmente (height 38px permite 2 linhas) ou em linha compacta.

**Layout compacto (padrão):**
```
  CPU  ▂▅█▃▂▁▆▅  39%    RAM  ████░░  61%    GPU  ██░░░  28%
```

**Hover → tooltip expandido com CPU por núcleo:**
```
╭─────────────────────────────────╮
│ CPU  ▂▅█▃▂▁▆▅  39%  avg         │
│  0 ▂  22%   1 ▅  44%            │
│  2 █  78%   3 ▃  31%            │
│  4 ▂  12%   5 ▅  55%            │
│  6 █  43%   7 ▅  29%            │
│                                  │
│ RAM   9.8 GiB / 16 GiB   61%    │
│ GPU   28%  │  VRAM  4.1/8.0 GiB │
│ NET  ↑ 1.2M  ↓ 4.5M             │
╰─────────────────────────────────╯
```

**Cores das barras (dinâmicas):**
| Uso | Cor da barra |
|---|---|
| 0–60% | `#22C55E` (verde) |
| 60–80% | `#F59E0B` (amarelo/laranja) |
| 80–100% | `#F43F5E` (vermelho) |

Barras preenchidas com caracteres Unicode block: `▏▎▍▌▋▊▉█` + `░▒▓`.

### Zona 5 — Tray + Áudio (extrema direita)

Ícones do system tray com espaçamento generoso. Áudio como widget pill:

```
╭──────────╮
│ 🔊  74%  │  ← clique → slider vertical popup
╰──────────╯
```

Rede compacta com ícone + `↑↓`:
```
  ↑ 1.2M
  ↓ 4.5M
```

---

### Animações

| Evento | Animação |
|---|---|
| Troca de workspace | Pill desliza para o ativo (150ms ease-out) |
| Nova janela aberta | Título faz fade-in (100ms) |
| Métrica crítica | Barra pisca 1x suavemente (não irritante) |
| Hover em métrica | Tooltip aparece (120ms fade) |
| Clique em ícone | Pulse rápido (80ms) |

---

### JSON payload do daemon (atualização 500ms)

```json
{
  "cpu":    { "total": 39, "cores": [22, 44, 78, 31, 12, 55, 43, 29] },
  "memory": { "used_percent": 61, "used_gib": 9.8, "total_gib": 16.0 },
  "gpu":    { "usage_percent": 28, "vram_used_gib": 4.1, "vram_total_gib": 8.0 },
  "network":{ "up_kbps": 1228, "down_kbps": 4608 },
  "audio":  { "volume": 74, "muted": false },
  "battery":{ "percent": 87, "charging": true }
}
```

---

## Kryonix Launcher

Ativado por `Super` ou `Super+Space`.

```
┌──────────────────────────────────────────────────────┐
│  Search apps, commands, files, brain...               │
│                                                      │
│  Aplicativos recentes                                │
│  ○ Kitty         ○ Firefox    ○ Obsidian             │
│                                                      │
│  Comandos                                            │
│  > brain status    > focus mode    > rebuild check   │
│                                                      │
│  Workspaces                                          │
│  1: dev    2: web    3: brain    4: infra    5: media │
└──────────────────────────────────────────────────────┘
```

Seções: Apps · Comandos Kryonix · Arquivos recentes · Workspaces · Brain (opt-in).

---

## Kryonix Control Center

App Kirigami com abas. Ativado por `Super+C` ou clique na barra.

### Aba Aparência

```
Cor de destaque:    [ #38BDF8 ▐████ ]
Transparência:      [ ▓▓▓▓▓░░░ 0.72 ]
Borda:              [ ON/OFF ]
Radius:             [ ▓▓▓░░ 14px ]
Fonte:              [ JetBrains Mono 11 ]
Blur:               [ OFF ] (fixo por design)
```

### Aba Bar

```
Posição:            [ Topo | Base ]
Altura:             [ ▓▓▓░░ 34px ]
CPU por núcleo:     [ ON/OFF ]
GPU:                [ ON/OFF ]
Rede:               [ ON/OFF ]
Intervalo:          [ ▓░░░░ 500ms ]
```

### Aba Atalhos

Visualização dos binds ativos com campo de edição. Gera `keybinds.toml`.

### Aba Perfis

```
○ Produtivo     ● Developer     ○ Minimal     ○ Gaming     ○ Cliente
                ↓
  [Aplicar Preview]  [Exportar HM]  [Aplicar HM]  [Rollback]
```

### Fluxo de persistência

```
Usuário edita no Control Center
        ↓
settings.toml atualizado (inotify → daemon → shell aplica < 1s)
        ↓ [Exportar HM]
kryonix-shell.generated.nix gerado + commit downstream
        ↓ [Aplicar HM]
kryonix home (com confirmação)
        ↓
Home Manager activation (mkOutOfStoreSymlink preserva settings)
```

---

## SDDM Kryonix Aurora

```
┌────────────────────────────────────────────────────┐
│                                                    │
│                   KRYONIX                          │
│               ≡ aurora shell                       │
│                                                    │
│            ┌────────────────────┐                  │
│            │ rocha              │                  │
│            ├────────────────────┤                  │
│            │ ●●●●●●●●           │                  │
│            │          [Entrar]  │                  │
│            └────────────────────┘                  │
│                                                    │
│   Plasma 6 Wayland     22:48  ↺ Reboot  ⏻ Desligar│
└────────────────────────────────────────────────────┘
```

- Fundo escuro `#050A10` com grade sutil azul.
- Card `rgba(8,13,22,0.88)` com borda `#38BDF8 33%`.
- Logo Kryonix + slogan "aurora shell".
- Hostname discreto, session selector (Plasma Wayland default).
- Seletor de sessão: Plasma Wayland, Hyprland (se disponível).
- Fallback: `theme = "breeze"` sempre coinstalado. Rollback imediato.

---

## Atalhos Aurora Shell

Atalhos adicionais sobre os atalhos Hyprland/KDE existentes:

| Atalho | Ação |
|---|---|
| Super | Launcher |
| Super+Enter | Terminal (Kitty) |
| Super+E | Dolphin |
| Super+B | Browser |
| Super+Space | Command palette |
| Super+Q | Fechar janela |
| Super+F | Fullscreen |
| Super+Shift+F | Float toggle |
| Super+H/J/K/L | Foco entre janelas |
| Super+Shift+H/J/K/L | Mover janela |
| Super+1..9 | Workspace |
| Super+Shift+1..9 | Mover para workspace |
| Super+Tab | Overview |
| Super+C | Control Center |
| Super+A | Action Center (drawer direito) |
| Super+P | Perfis (seletor rápido) |
| Super+Esc | System monitor |
| Super+X | Command palette Kryonix (opt-in) |
| Super+I | Brain quick ask (opt-in) |

---

## Perfis declarativos

```nix
kryonix.aurora.profile = "productive";
```

| Perfil | Bar | Transparência | Tiling | Apps padrão |
|---|---|---|---|---|
| `minimal` | clock + tray | off | off | terminal, browser |
| `productive` | completa | controlada | on | terminal, dolphin, browser |
| `developer` | CPU/core destaque | terminal 84% | on | kitty, helix, browser, obsidian |
| `gaming` | off | off | off | Steam, Discord |
| `client` | clock + tray | suave | optional | apps configuráveis |

---

## Transparência — regras por app

Nunca global. Sempre por classe de janela via KWin window rules.

| Classe | Opacidade | Motivo |
|---|---|---|
| `konsole`, `kitty`, `alacritty` | 84% | Terminal leve transparente |
| `dolphin` | 92% | File manager levemente transparente |
| `krunner`, launcher | 86% | Launcher flutuante |
| Painel, bar | 78% | UI do shell |
| `systemsettings` | 90% | Settings leve |
| `firefox`, `chromium` | 100% | Browser opaco (legibilidade) |
| IDEs, editors | 100% | Opaco (foco) |
| Electron apps | 100% | Opaco (performance) |

`blur = false` em todos — regra inviolável de design.
