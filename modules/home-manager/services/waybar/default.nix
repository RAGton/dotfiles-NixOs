# =============================================================================
# Home Manager: Kryonix Bar (Waybar — PR 7C)
#
# O que é:
# - Barra premium do Kryonix Shell sobre Hyprland.
# - Floating island com border-radius 16px, paleta Kryonix Dark.
# - CPU per-core via ícones nativos do Waybar ({icon0}…{iconN}).
# - Desativada automaticamente quando Caelestia está ativa (elle provê sua barra).
#
# Por quê:
# - Waybar é declarativo via HM, sem daemon extra no V1.
# - CPU per-core via format-icons é nativo; sem script shell ou D-Bus ainda.
# - Daemon Rust (kryonix-shell-daemon) integra-se no PR 7D sem mudar este módulo.
#
# Como:
# - Importar em desktop/hyprland/kryonix-bar.nix (opt-in).
# - Ativado quando kryonix.shell.backend != "caelestia".
# =============================================================================
{ config, lib, ... }:
let
  shellBackend = config.kryonix.shell.backend or null;
  shellProvidesBar = shellBackend == "caelestia";

  # Paleta Kryonix Dark — tokens centrais
  c = {
    bg = "rgba(8, 13, 22, 0.84)";
    bgHover = "rgba(14, 20, 32, 0.90)";
    surface = "rgba(17, 24, 39, 0.70)";
    border = "rgba(56, 189, 248, 0.18)";
    borderHot = "rgba(56, 189, 248, 0.45)";
    accent = "#38BDF8";
    accentBg = "rgba(56, 189, 248, 0.15)";
    text = "#E5E7EB";
    muted = "#64748B";
    muted2 = "#94A3B8";
    success = "#22C55E";
    successBg = "rgba(34, 197, 94, 0.15)";
    warning = "#F59E0B";
    warningBg = "rgba(245, 158, 11, 0.15)";
    danger = "#F43F5E";
    dangerBg = "rgba(244, 63, 94, 0.15)";
    tooltip = "rgba(11, 18, 32, 0.95)";
    shadow = "rgba(0, 0, 0, 0.50)";
  };
in
{
  config = lib.mkIf (!shellProvidesBar) {
    programs.waybar = {
      enable = true;
      systemd.enable = true;

      settings = {
        mainBar = {
          layer = "top";
          position = "top";
          exclusive = true;
          passthrough = false;
          fixed-center = true;
          ipc = true;

          # Floating island: 6px do topo e laterais
          margin-top = 6;
          margin-left = 8;
          margin-right = 8;

          # Layout: workspaces + window | clock | métricas + áudio + tray
          modules-left = [
            "hyprland/workspaces"
            "hyprland/window"
          ];

          modules-center = [
            "clock"
          ];

          modules-right = [
            "cpu"
            "memory"
            "network"
            "pulseaudio"
            "battery"
            "tray"
          ];

          # ── Workspaces ─────────────────────────────────────────────────────
          "hyprland/workspaces" = {
            all-outputs = true;
            format = "{name}";
            on-click = "activate";
            show-special = false;
            sort-by-number = true;
            on-scroll-up = "hyprctl dispatch workspace e+1";
            on-scroll-down = "hyprctl dispatch workspace e-1";
          };

          # ── Título da janela ativa ─────────────────────────────────────────
          "hyprland/window" = {
            max-length = 48;
            separate-outputs = false;
            rewrite = {
              "(.*) — Mozilla Firefox" = " $1";
              "(.*) - fish" = " $1";
              "(.*) - nvim" = " $1";
              "kitty" = "";
              "dolphin" = " Arquivos";
            };
          };

          # ── Relógio ────────────────────────────────────────────────────────
          clock = {
            format = "<b>{:%H:%M}</b>";
            format-alt = "{:%A, %d %b %Y}";
            tooltip-format = "<tt><small>{calendar}</small></tt>";
            calendar = {
              mode = "month";
              weeks-pos = "right";
              on-scroll = 1;
              format = {
                months = "<span color='${c.accent}'><b>{}</b></span>";
                days = "<span color='${c.text}'>{}</span>";
                weeks = "<span color='${c.muted2}'><b>W{}</b></span>";
                weekdays = "<span color='${c.muted2}'><b>{}</b></span>";
                today = "<span color='${c.accent}'><b><u>{}</u></b></span>";
              };
            };
          };

          # ── CPU — per-core via icons nativos do Waybar ────────────────────
          # Waybar suporta {icon0}…{iconN} para cada núcleo lógico.
          # format-icons mapeia % → caractere de bloco Unicode.
          cpu = {
            interval = 1;
            format = "{icon0}{icon1}{icon2}{icon3}{icon4}{icon5}{icon6}{icon7} <span color='${c.muted2}'>{usage}%</span>";
            format-icons = [
              "▁"
              "▂"
              "▃"
              "▄"
              "▅"
              "▆"
              "▇"
              "█"
            ];
            tooltip = true;
            tooltip-format = "CPU {usage}%\n{icon0} {usage0}%  {icon1} {usage1}%\n{icon2} {usage2}%  {icon3} {usage3}%\n{icon4} {usage4}%  {icon5} {usage5}%\n{icon6} {usage6}%  {icon7} {usage7}%";
            on-click-right = "kitty btop";
          };

          # ── RAM ────────────────────────────────────────────────────────────
          memory = {
            interval = 5;
            format = "󰾆 <span color='${c.muted2}'>{percentage}%</span>";
            format-alt = "󰾆 {used:0.1f}/{total:0.1f}G";
            tooltip = true;
            tooltip-format = "RAM: {used:0.1f} GiB usados de {total:0.1f} GiB ({percentage}%)";
            on-click-right = "kitty btop";
          };

          # ── Rede ───────────────────────────────────────────────────────────
          network = {
            interval = 2;
            format-wifi = "󰖩 <span color='${c.muted2}'>↑{bandwidthUpBytes} ↓{bandwidthDownBytes}</span>";
            format-ethernet = "󰈀 <span color='${c.muted2}'>↑{bandwidthUpBytes} ↓{bandwidthDownBytes}</span>";
            format-disconnected = "<span color='${c.danger}'>󰖪 offline</span>";
            tooltip-format = "{ifname}: {ipaddr}/{cidr}";
            tooltip-format-wifi = "{essid} ({signalStrength}%)  {ipaddr}";
          };

          # ── Áudio ──────────────────────────────────────────────────────────
          pulseaudio = {
            format = "{icon} <span color='${c.muted2}'>{volume}%</span>";
            format-muted = "<span color='${c.muted}'>󰝟 mudo</span>";
            format-icons = {
              default = [
                "󰕿"
                "󰖀"
                "󰕾"
              ];
            };
            on-click = "pavucontrol";
            on-scroll-up = "pamixer -i 3";
            on-scroll-down = "pamixer -d 3";
            on-click-right = "pamixer -t";
            smooth-scrolling-threshold = 1;
            ignored-sinks = [ "Easy Effects Sink" ];
            tooltip = true;
            tooltip-format = "{desc}";
          };

          # ── Bateria ────────────────────────────────────────────────────────
          battery = {
            interval = 30;
            states = {
              warning = 30;
              critical = 15;
            };
            format = "{icon} <span color='${c.muted2}'>{capacity}%</span>";
            format-charging = "󰂄 {capacity}%";
            format-plugged = "󰚥 {capacity}%";
            format-icons = [
              "󰂎"
              "󰁺"
              "󰁻"
              "󰁼"
              "󰁽"
              "󰁾"
              "󰁿"
              "󰂀"
              "󰂁"
              "󰂂"
              "󰁹"
            ];
            tooltip-format = "{timeTo} — {power:.1f}W";
          };

          # ── System Tray ────────────────────────────────────────────────────
          tray = {
            spacing = 8;
            icon-size = 16;
          };
        };
      };

      # ── CSS — Kryonix Dark Premium ─────────────────────────────────────────
      style = ''
        /* Reset global */
        * {
          font-family: "JetBrainsMono Nerd Font", "CaskaydiaCove Nerd Font", monospace;
          font-size:   12px;
          font-weight: 400;
          min-height:  0;
          padding:     0;
          margin:      0;
          border:      none;
          border-radius: 0;
        }

        /* Janela principal: floating island */
        window#waybar {
          background:    ${c.bg};
          border:        1px solid ${c.border};
          border-radius: 16px;
          box-shadow:    0 4px 24px ${c.shadow}, 0 1px 0 rgba(255,255,255,0.04) inset;
        }

        window#waybar.hidden { opacity: 0.3; }

        /* Grupos de módulos: sem fundo próprio (herdam o da janela) */
        .modules-left,
        .modules-center,
        .modules-right {
          background: transparent;
          padding: 0 6px;
        }

        /* Separadores visuais entre grupos */
        .modules-left   { padding-left: 10px; }
        .modules-right  { padding-right: 10px; }

        /* ── Tooltip ───────────────────────────────────────────────────── */
        tooltip {
          background:    ${c.tooltip};
          border:        1px solid ${c.border};
          border-radius: 10px;
          padding:       6px 10px;
          color:         ${c.text};
          box-shadow:    0 4px 16px ${c.shadow};
        }
        tooltip label {
          color: ${c.text};
          font-size: 11px;
        }

        /* ── Módulos base ──────────────────────────────────────────────── */
        #backlight, #battery, #bluetooth, #clock, #cpu,
        #custom-notification, #language, #memory, #network,
        #privacy, #pulseaudio, #tray, #temperature, #workspaces,
        #window {
          color:         ${c.text};
          padding:       4px 10px;
          border-radius: 10px;
          margin:        3px 1px;
        }

        /* ── Workspaces ─────────────────────────────────────────────────── */
        #workspaces {
          padding: 0 4px;
          margin:  0;
          background: transparent;
        }

        #workspaces button {
          color:         ${c.muted};
          background:    rgba(255,255,255,0.04);
          border:        1px solid rgba(255,255,255,0.06);
          border-radius: 10px;
          padding:       2px 10px;
          margin:        3px 2px;
          min-width:     24px;
          transition:    all 120ms ease;
        }

        #workspaces button.active {
          color:      ${c.accent};
          background: ${c.accentBg};
          border:     1px solid ${c.borderHot};
          font-weight: 700;
        }

        #workspaces button.occupied {
          color:      ${c.muted2};
          background: rgba(255,255,255,0.07);
          border:     1px solid rgba(255,255,255,0.09);
        }

        #workspaces button.urgent {
          color:      ${c.danger};
          background: ${c.dangerBg};
          border:     1px solid ${c.danger};
        }

        #workspaces button:hover {
          color:      ${c.text};
          background: rgba(56, 189, 248, 0.08);
          border:     1px solid rgba(56, 189, 248, 0.22);
        }

        /* ── Window title ─────────────────────────────────────────────── */
        #window {
          color:    ${c.muted2};
          font-size: 11px;
          padding:  4px 8px;
          background: transparent;
        }

        /* ── Clock ────────────────────────────────────────────────────── */
        #clock {
          color:       ${c.text};
          font-size:   13px;
          font-weight: 700;
          padding:     4px 14px;
          letter-spacing: 0.5px;
        }

        /* ── CPU — barras por núcleo ──────────────────────────────────── */
        #cpu {
          font-size: 11px;
          letter-spacing: -0.5px; /* empilha os chars de bloco */
        }

        /* cor dinâmica via classes CSS injetadas pelo Waybar */
        #cpu.warning  { color: ${c.warning}; }
        #cpu.critical { color: ${c.danger};  }

        /* ── RAM ───────────────────────────────────────────────────────── */
        #memory { font-size: 11px; }
        #memory.warning  { color: ${c.warning}; }
        #memory.critical { color: ${c.danger};  }

        /* ── Rede ──────────────────────────────────────────────────────── */
        #network { font-size: 11px; }
        #network.disconnected { color: ${c.danger}; }

        /* ── Áudio ─────────────────────────────────────────────────────── */
        #pulseaudio { font-size: 12px; }
        #pulseaudio.muted { color: ${c.muted}; }

        /* ── Bateria ───────────────────────────────────────────────────── */
        #battery.charging { color: ${c.success}; }
        #battery.plugged  { color: ${c.success}; }
        #battery.warning:not(.charging) {
          color: ${c.warning};
          background: ${c.warningBg};
        }
        #battery.critical:not(.charging) {
          color: ${c.danger};
          background: ${c.dangerBg};
          animation: blink 800ms steps(1) infinite;
        }

        @keyframes blink {
          50% { opacity: 0.4; }
        }

        /* ── Tray ──────────────────────────────────────────────────────── */
        #tray {
          padding: 4px 8px;
        }
        #tray > .passive { -gtk-icon-effect: dim; }
        #tray > .needs-attention {
          -gtk-icon-effect: highlight;
          background: ${c.dangerBg};
          border-radius: 8px;
        }
      '';
    };
  };
}
