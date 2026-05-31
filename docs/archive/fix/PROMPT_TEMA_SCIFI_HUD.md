# Prompt: Tema Kryonix — Sci-Fi HUD / Terminal Aesthetic

> Executar no Claude Code com acesso a `/etc/kryonix`.
> Objetivo: tema visual único, futurista, construído em volta das artes do usuário.
> Arte: mistura de estilos. Estética: sci-fi HUD / terminal. Lock screen: interativo.

---

## Contexto do projeto

- Desktop: Hyprland + Caelestia (shell)
- Wallpaper daemon atual: gerenciado pelo Caelestia (`caelestia wallpaper`)
- Lock screen atual: não configurado (apenas hypridle)
- Fonte de arte do usuário: `files/wallpaper/` (adicionar artes aqui)
- Namespace de opções: `kryonix.*`
- Home Manager: `home/rocha/inspiron/default.nix`

---

## FASE 1 — Inventário e preparação

### 1.1 Ler o estado atual

```bash
# Ver o que já existe de theming
find /etc/kryonix/desktop/hyprland -name '*.nix' | sort
find /etc/kryonix/files -type f | sort

# Ver o que o Caelestia já gerencia
cat /etc/kryonix/desktop/hyprland/rice/caelestia-config.nix 2>/dev/null || \
  grep -rn 'caelestia\|swww\|wallpaper' /etc/kryonix/desktop --include='*.nix' | head -20

# Pacotes já disponíveis
grep -rn 'hyprlock\|hypridle\|swww\|matugen\|playerctl' \
  /etc/kryonix --include='*.nix' --exclude-dir='.git' | head -20
```

### 1.2 Verificar fontes instaladas

```bash
grep -rn 'font\|nerd\|mono\|JetBrains\|Iosevka\|Geist' \
  /etc/kryonix --include='*.nix' --exclude-dir='.git' | grep 'package\|fonts\.' | head -10
```

Reportar o que existe antes de criar qualquer arquivo.

---

## FASE 2 — Paleta de cores sci-fi HUD

### 2.1 Paleta base declarativa

Criar `desktop/hyprland/theme/palette.nix` com a paleta canônica do Kryonix:

```nix
# desktop/hyprland/theme/palette.nix
# Paleta sci-fi HUD — derivada das artes do usuário
# Tons: espaço profundo (fundo), ciano frio (destaque), verde terminal (acento)
{
  bg0    = "0a0d12";   # fundo principal — espaço profundo
  bg1    = "0f1419";   # superfícies — painéis
  bg2    = "151b24";   # borda interna
  border = "1e2d3d";   # bordas de janela padrão

  # HUD colors — ciano elétrico
  hud1   = "00d4ff";   # destaque primário (titlebars, borders ativos)
  hud2   = "0099cc";   # destaque secundário (badges, indicadores)
  hud3   = "005580";   # destaque terciário (sombras coloridas)

  # Terminal green — acento
  term1  = "39ff14";   # verde neon — alertas, cursor
  term2  = "00cc00";   # verde médio
  term3  = "004400";   # verde escuro

  # Textos
  fg0    = "e8f4f8";   # texto principal
  fg1    = "8badbf";   # texto secundário
  fg2    = "4a6b7a";   # texto apagado / comentário

  # Estados
  red    = "ff4455";
  yellow = "ffcc00";
  purple = "b48eff";
}
```

### 2.2 Matugen para cores dinâmicas das artes

Adicionar `matugen` para extrair paleta Material You de cada wallpaper:

```nix
# Em home/rocha/default.nix ou common home module
programs.matugen = {
  enable = true;
  # Integra com o Caelestia — ao trocar wallpaper, paleta atualiza
};
```

---

## FASE 3 — Hyprland: visual sci-fi HUD

### 3.1 Criar `desktop/hyprland/theme/hyprland-look.nix`

Este arquivo define a aparência do Hyprland usando a paleta acima.

```nix
{ lib, ... }:
let
  p = import ./palette.nix;
in
{
  wayland.windowManager.hyprland.settings = {
    general = {
      border_size = 1;
      "col.active_border"   = "rgb(${p.hud1}) rgb(${p.hud3}) 45deg";
      "col.inactive_border" = "rgb(${p.border})";
      gaps_in  = 4;
      gaps_out = 8;
      layout   = "master";
    };

    decoration = {
      rounding = 6;

      # Blur sutil — HUD tem leveza, não é pesado
      blur = {
        enabled  = true;
        size     = 4;
        passes   = 2;
        noise    = 0.02;
        contrast = 0.9;
        xray     = false;
      };

      shadow = {
        enabled      = true;
        range        = 12;
        render_power = 2;
        color        = "rgba(00d4ff18)";  # sombra ciano
      };
    };

    animations = {
      enabled = true;

      # Bezier curvas suaves — fluido mas rápido
      bezier = [
        "snap,   0.19, 1.0, 0.22, 1.0"   # abertura rápida
        "glide,  0.4,  0.0, 0.2, 1.0"    # movimento suave
        "fade,   0.0,  0.0, 0.2, 1.0"    # fade limpo
      ];

      animation = [
        "windows,       1, 3,  snap,  popin 85%"
        "windowsOut,    1, 2,  fade,  popin 85%"
        "windowsMove,   1, 3,  glide"
        "border,        1, 8,  glide"
        "borderangle,   1, 12, glide"
        "fade,          1, 4,  fade"
        "workspaces,    1, 3,  glide, slidevert"
        "specialWorkspace, 1, 4, glide, slidefadevert 20%"
      ];
    };

    misc = {
      force_default_wallpaper  = 0;
      disable_hyprland_logo    = true;
      disable_splash_rendering = true;
      vfr = true;   # Variable Frame Rate — economiza GPU quando parado
      vrr = 1;      # Variable Refresh Rate — ativa se o monitor suportar
    };

    # Cursor
    cursor = {
      no_hardware_cursors = false;
    };
  };
}
```

### 3.2 Fontes sci-fi / terminal

Em `modules/home-manager/theme/fonts.nix` (criar se não existir):

```nix
{ pkgs, ... }:
{
  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    # Display — títulos HUD
    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })

    # Body / UI — leitura
    ibm-plex-mono

    # Fallback sem-serif limpo
    inter
  ];
}
```

Fonte principal da UI: **JetBrains Mono Nerd Font** — leitura excelente em terminais e painéis HUD.

---

## FASE 4 — Tela de bloqueio interativa

### 4.1 Criar `desktop/hyprland/theme/hyprlock.nix`

Este é o arquivo central da tela de bloqueio. Usa `hyprlock` com:
- Arte do usuário em fullscreen com blur
- Clock em fonte monoespaçada grande
- Player de música via `playerctl`
- Infos de sistema (hostname, usuário, uptime)
- Input de senha estilo terminal

```nix
{ config, pkgs, lib, ... }:
let
  p = import ./palette.nix;
  font = "JetBrains Mono Nerd Font";
in
{
  home.packages = [ pkgs.hyprlock pkgs.playerctl ];

  programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        disable_loading_bar   = true;
        hide_cursor           = true;
        grace                 = 0;
        no_fade_in            = false;
        no_fade_out           = false;
        ignore_empty_input    = true;
      };

      background = [
        {
          # Arte do usuário em fullscreen — blur forte para não competir com HUD
          path         = "screenshot";   # captura a tela atual
          blur_size    = 6;
          blur_passes  = 3;
          noise        = 0.02;
          contrast     = 0.85;
          brightness   = 0.7;
          vibrancy     = 0.15;
          vibrancy_darkness = 0.2;
        }
      ];

      # ── CLOCK ──────────────────────────────────────────────
      label = [
        {
          # Hora — grande, centro-superior
          text      = "cmd[update:1000] echo $(date +'%H:%M:%S')";
          font_size = 96;
          font_family = font;
          color     = "rgb(${p.hud1})";
          position  = "0, 280";
          halign    = "center";
          valign    = "center";
          shadow_passes = 2;
          shadow_size   = 8;
          shadow_color  = "rgb(${p.hud3})";
        }
        {
          # Data — menor, abaixo da hora
          text      = "cmd[update:60000] echo $(date +'%A, %d %B %Y')";
          font_size = 18;
          font_family = font;
          color     = "rgb(${p.fg1})";
          position  = "0, 180";
          halign    = "center";
          valign    = "center";
        }

        # ── PLAYER DE MÚSICA ─────────────────────────────────
        {
          # Ícone do player
          text      = "cmd[update:2000] playerctl status 2>/dev/null | grep -q Playing && echo '󰎈' || echo '󰎊'";
          font_size = 20;
          font_family = font;
          color     = "rgb(${p.term1})";
          position  = "-220, -20";
          halign    = "center";
          valign    = "center";
        }
        {
          # Track atual
          text = ''
            cmd[update:2000] playerctl metadata --format '{{artist}} — {{title}}' 2>/dev/null \
              | cut -c1-50 || echo "sem reprodução"
          '';
          font_size   = 14;
          font_family = font;
          color       = "rgb(${p.fg0})";
          position    = "0, -20";
          halign      = "center";
          valign      = "center";
        }
        {
          # Barra de progresso simulada com tempo
          text = ''
            cmd[update:1000] \
              pos=$(playerctl position 2>/dev/null | cut -d. -f1) && \
              dur=$(playerctl metadata mpris:length 2>/dev/null | awk '{printf "%d", $1/1000000}') && \
              [ -n "$pos" ] && [ -n "$dur" ] && \
              printf "%d:%02d / %d:%02d" $((pos/60)) $((pos%60)) $((dur/60)) $((dur%60)) \
              || echo ""
          '';
          font_size   = 12;
          font_family = font;
          color       = "rgb(${p.fg2})";
          position    = "0, -42";
          halign      = "center";
          valign      = "center";
        }

        # ── INFOS DO SISTEMA ──────────────────────────────────
        {
          # Hostname + usuário — canto inferior esquerdo
          text        = "  ${config.networking.hostName}  ·  ${config.home.username}";
          font_size   = 13;
          font_family = font;
          color       = "rgb(${p.hud2})";
          position    = "40, 40";
          halign      = "left";
          valign      = "bottom";
        }
        {
          # CPU + RAM — canto inferior direito
          text = ''
            cmd[update:3000] \
              cpu=$(grep 'cpu ' /proc/stat | awk '{u=$2+$4; t=$2+$4+$5; print int(u*100/t) "%"}') && \
              ram=$(free -h | awk '/^Mem/{print $3"/"$2}') && \
              echo "  $cpu    $ram"
          '';
          font_size   = 13;
          font_family = font;
          color       = "rgb(${p.term2})";
          position    = "-40, 40";
          halign      = "right";
          valign      = "bottom";
        }
        {
          # Uptime — canto superior direito
          text        = "cmd[update:60000] uptime -p | sed 's/up /⏱ /'";
          font_size   = 12;
          font_family = font;
          color       = "rgb(${p.fg2})";
          position    = "-40, -40";
          halign      = "right";
          valign      = "top";
        }
      ];

      # ── INPUT DE SENHA — estilo terminal ──────────────────
      input-field = [
        {
          size             = "280, 42";
          position         = "0, -140";
          halign           = "center";
          valign           = "center";

          # Visual terminal
          outline_thickness = 1;
          outer_color       = "rgb(${p.hud1})";
          inner_color       = "rgb(${p.bg1})";
          font_color        = "rgb(${p.fg0})";
          font_family       = font;
          font_size         = 14;

          # Placeholder HUD
          placeholder_text  = "<span foreground='##${p.fg2}'>[ AUTHENTICATE ]</span>";

          # Feedback visual
          fail_color        = "rgb(${p.red})";
          check_color       = "rgb(${p.term1})";
          capslock_color    = "rgb(${p.yellow})";

          dots_size         = 0.28;
          dots_spacing      = 0.3;
          dots_center       = true;
          dots_rounding     = -1;

          # Sem borda arredondada demais — estilo HUD
          rounding          = 4;

          fade_on_empty     = true;
          hide_input        = false;
        }
      ];
    };
  };
}
```

### 4.2 Criar `desktop/hyprland/theme/hypridle.nix`

Controla quando o bloqueio ativa:

```nix
{ pkgs, ... }:
{
  services.hypridle = {
    enable = true;

    settings = {
      general = {
        lock_cmd        = "hyprlock";
        before_sleep_cmd = "hyprlock";
        after_sleep_cmd  = "hyprctl dispatch dpms on";
        ignore_dbus_inhibit = false;
      };

      listener = [
        {
          # Dim após 4 min
          timeout  = 240;
          on-timeout  = "brightnessctl -s set 30%";
          on-resume   = "brightnessctl -r";
        }
        {
          # Bloquear após 6 min
          timeout  = 360;
          on-timeout  = "hyprlock";
        }
        {
          # Desligar tela após 10 min
          timeout  = 600;
          on-timeout  = "hyprctl dispatch dpms off";
          on-resume   = "hyprctl dispatch dpms on";
        }
      ];
    };
  };
}
```

---

## FASE 5 — Wallpaper com transições fluidas

### 5.1 Criar `desktop/hyprland/theme/wallpaper.nix`

```nix
{ pkgs, ... }:
{
  home.packages = [ pkgs.swww pkgs.matugen ];

  # Script de troca de wallpaper com transição sci-fi
  home.file.".local/bin/kryonix-wallpaper" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Uso: kryonix-wallpaper [caminho/para/arte.png]
      #      kryonix-wallpaper --random
      #      kryonix-wallpaper --next

      WALL_DIR="$HOME/.local/share/wallpaper"
      STATE_FILE="$HOME/.local/state/kryonix/wallpaper-current"

      mkdir -p "$WALL_DIR" "$(dirname "$STATE_FILE")"

      set_wall() {
        local img="$1"
        [ -f "$img" ] || { echo "Arquivo não encontrado: $img"; exit 1; }

        # Transição: wipe da esquerda para direita — estilo scan de HUD
        swww img "$img" \
          --transition-type wipe \
          --transition-angle 30 \
          --transition-duration 1.2 \
          --transition-fps 60 \
          --transition-bezier 0.4,0.0,0.2,1.0

        echo "$img" > "$STATE_FILE"

        # Gerar paleta de cores a partir da arte
        matugen image "$img" --mode dark 2>/dev/null &

        notify-send "🖼 Kryonix Wallpaper" "$(basename "$img")" \
          --icon "image-x-generic" --expire-time 2000
      }

      case "$1" in
        --random)
          img=$(find "$WALL_DIR" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.webp' \) | shuf -n1)
          set_wall "$img"
          ;;
        --next)
          current=$(cat "$STATE_FILE" 2>/dev/null)
          imgs=( $(find "$WALL_DIR" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.webp' \) | sort) )
          idx=0
          for i in "''${!imgs[@]}"; do
            [ "''${imgs[$i]}" = "$current" ] && idx=$(( (i+1) % ''${#imgs[@]} ))
          done
          set_wall "''${imgs[$idx]}"
          ;;
        "")
          # Sem argumento — restaura o último ou escolhe aleatório
          current=$(cat "$STATE_FILE" 2>/dev/null)
          [ -f "$current" ] && set_wall "$current" || $0 --random
          ;;
        *)
          set_wall "$1"
          ;;
      esac
    '';
  };

  # Inicializar swww e restaurar wallpaper na sessão
  wayland.windowManager.hyprland.settings.exec-once = [
    "swww-daemon --format xrgb"
    "sleep 0.5 && kryonix-wallpaper"
  ];
}
```

### 5.2 Atalhos de wallpaper no Hyprland

Adicionar em `desktop/hyprland/hyprland.conf`:

```
# Wallpaper
bind = $mainMod ALT, W, exec, kryonix-wallpaper --next
bind = $mainMod CTRL ALT, W, exec, kryonix-wallpaper --random
```

---

## FASE 6 — GTK Theme sci-fi

### 6.1 Criar `desktop/hyprland/theme/gtk.nix`

```nix
{ pkgs, ... }:
{
  gtk = {
    enable = true;

    theme = {
      name    = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };

    iconTheme = {
      name    = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    cursorTheme = {
      name    = "Bibata-Modern-Ice";   # cursor branco/ciano — combina com HUD
      package = pkgs.bibata-cursors;
      size    = 24;
    };

    font = {
      name    = "Inter";
      size    = 10;
    };
  };

  qt = {
    enable      = true;
    platformTheme.name = "gtk";
    style.name  = "adwaita-dark";
  };

  # Variáveis de ambiente para cursor e escala
  home.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE  = "24";
    GTK_THEME     = "adw-gtk3-dark";
  };
}
```

---

## FASE 7 — Módulo central e integração

### 7.1 Criar `desktop/hyprland/theme/default.nix`

Ponto de entrada que importa tudo:

```nix
{ ... }:
{
  imports = [
    ./hyprland-look.nix
    ./hyprlock.nix
    ./hypridle.nix
    ./wallpaper.nix
    ./gtk.nix
  ];
}
```

### 7.2 Adicionar ao `desktop/hyprland/user.nix`

```nix
imports = [
  # ... imports existentes ...
  ./theme      # ← adicionar
];
```

### 7.3 Adicionar pacotes ao home

Em `modules/home-manager/common/default.nix` ou similar:

```nix
home.packages = with pkgs; [
  brightnessctl   # controle de brilho para hypridle
  playerctl       # controle de player para lock screen
  swww            # wallpaper daemon
  matugen         # paleta dinâmica das artes
  hyprlock        # lock screen
];
```

---

## FASE 8 — Validação

### 8.1 Checklist de avaliação

```bash
nix flake check /etc/kryonix --keep-going 2>&1 | grep '^error' | head -10
nix eval /etc/kryonix#homeConfigurations."rocha@inspiron".config.programs.hyprlock.enable
nix eval /etc/kryonix#homeConfigurations."rocha@inspiron".config.services.hypridle.enable
```

### 8.2 Test antes de switch

```bash
# Home Manager primeiro (sem reiniciar o sistema)
home-manager switch --flake /etc/kryonix#rocha@inspiron

# Verificar lock screen
hyprlock &
# Deve mostrar: HUD, clock atualizado, player, infos de sistema, input de senha

# Verificar wallpaper
swww-daemon &
kryonix-wallpaper --random

# Verificar atalhos no Hyprland
# Super+Alt+W → próximo wallpaper
# Super+L → bloqueia com hyprlock
```

### 8.3 Commit

```bash
git -C /etc/kryonix add desktop/hyprland/theme/ desktop/hyprland/user.nix
git -C /etc/kryonix commit -m "feat: tema Kryonix sci-fi HUD

- palette.nix: paleta canônica espaço/ciano/terminal-verde
- hyprland-look.nix: borders HUD, blur sutil, animações fluidas
- hyprlock.nix: clock HUD, player (playerctl), stats CPU/RAM, input terminal
- hypridle.nix: dim 4min, lock 6min, dpms 10min
- wallpaper.nix: swww + transição wipe 1.2s + matugen paleta dinâmica
- gtk.nix: adw-gtk3-dark, Papirus-Dark, cursor Bibata-Ice
- Super+Alt+W = próximo wallpaper / Super+Ctrl+Alt+W = aleatório"
```

---

## Regras

- Não usar CSS hardcoded — tudo via `palette.nix` para facilitar troca de cores
- `exec-once` no Hyprland usa `${pkgs.swww}/bin/swww-daemon` (path absoluto)
- Testar o hyprlock em TTY antes de commitar: `hyprlock` no terminal
- Se o `matugen` não estiver no nixpkgs estável, verificar disponibilidade antes de adicionar
- Reportar o estado de cada arquivo antes e depois de editar
- Validar que `swww` não conflita com o daemon de wallpaper do Caelestia (checar o que já roda no `exec-once`)

---

## Próximos passos após implementação

1. **Adicionar suas artes** em `~/.local/share/wallpaper/` — o script detecta automaticamente
2. **Ajustar a paleta** em `desktop/hyprland/theme/palette.nix` para combinar com suas artes
3. **Fonte alternativa**: se quiser estética mais agressiva, testar `Iosevka Term` ou `Hack Nerd Font`
4. **Waybar sci-fi**: criar `desktop/hyprland/theme/waybar.nix` com módulos de HUD (próximo passo)
