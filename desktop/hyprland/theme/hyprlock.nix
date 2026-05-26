{ pkgs, ... }:
let
  p = import ./palette.nix;
  font = "JetBrains Mono Nerd Font";
in
{
  home.packages = [
    pkgs.hyprlock
    pkgs.playerctl
  ];

  programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        hide_cursor = true;
        ignore_empty_input = true;
      };

      background = [
        {
          # Arte do usuário em fullscreen — blur forte para não competir com HUD
          path = "screenshot"; # captura a tela atual
          blur_size = 6;
          blur_passes = 3;
          noise = 0.02;
          contrast = 0.85;
          brightness = 0.7;
          vibrancy = 0.15;
          vibrancy_darkness = 0.2;
        }
      ];

      # ── CLOCK ──────────────────────────────────────────────
      label = [
        {
          # Hora — grande, centro-superior
          text = "cmd[update:1000] echo $(date +'%H:%M:%S')";
          font_size = 96;
          font_family = font;
          color = "rgb(${p.hud1})";
          position = "0, 280";
          halign = "center";
          valign = "center";
          shadow_passes = 2;
          shadow_size = 8;
          shadow_color = "rgb(${p.hud3})";
        }
        {
          # Data — menor, abaixo da hora
          text = "cmd[update:60000] echo $(date +'%A, %d %B %Y')";
          font_size = 18;
          font_family = font;
          color = "rgb(${p.fg1})";
          position = "0, 180";
          halign = "center";
          valign = "center";
        }

        # ── PLAYER DE MÚSICA ─────────────────────────────────
        {
          # Ícone do player
          text = "cmd[update:2000] playerctl status 2>/dev/null | grep -q Playing && echo '󰎈' || echo '󰎊'";
          font_size = 20;
          font_family = font;
          color = "rgb(${p.term1})";
          position = "-220, -20";
          halign = "center";
          valign = "center";
        }
        {
          # Track atual
          text = ''
            cmd[update:2000] playerctl metadata --format '{{artist}} — {{title}}' 2>/dev/null \
              | cut -c1-50 || echo "sem reprodução"
          '';
          font_size = 14;
          font_family = font;
          color = "rgb(${p.fg0})";
          position = "0, -20";
          halign = "center";
          valign = "center";
        }
        {
          # Barra de progresso simulada com tempo
          text = "cmd[update:1000] ${pkgs.writeShellScript "player-status" ''
            pos=$(${pkgs.playerctl}/bin/playerctl position 2>/dev/null | cut -d. -f1)
            dur=$(${pkgs.playerctl}/bin/playerctl metadata mpris:length 2>/dev/null | awk '{printf "%d", $1/1000000}')
            [ -z "$pos" ] || [ -z "$dur" ] && exit 0
            printf "%d:%02d / %d:%02d" $((pos/60)) $((pos%60)) $((dur/60)) $((dur%60))
          ''}";
          font_size = 12;
          font_family = font;
          color = "rgb(${p.fg2})";
          position = "0, -42";
          halign = "center";
          valign = "center";
        }

        # ── INFOS DO SISTEMA ──────────────────────────────────
        {
          # Hostname + usuário — canto inferior esquerdo
          text = "cmd[update:600000] echo \"  $(hostname)  ·  $USER\"";
          font_size = 13;
          font_family = font;
          color = "rgb(${p.hud2})";
          position = "40, 40";
          halign = "left";
          valign = "bottom";
        }
        {
          # CPU + RAM — canto inferior direito
          text = ''
            cmd[update:3000] \
              cpu=$(grep 'cpu ' /proc/stat | awk '{u=$2+$4; t=$2+$4+$5; print int(u*100/t) "%"}') && \
              ram=$(free -h | awk '/^Mem/{print $3"/"$2}') && \
              echo "  $cpu    $ram"
          '';
          font_size = 13;
          font_family = font;
          color = "rgb(${p.term2})";
          position = "-40, 40";
          halign = "right";
          valign = "bottom";
        }
        {
          # Uptime — canto superior direito
          text = "cmd[update:60000] uptime | awk -F'up ' '{print \"⏱ \" $2}' | awk -F',' '{print $1}'";
          font_size = 12;
          font_family = font;
          color = "rgb(${p.fg2})";
          position = "-40, -40";
          halign = "right";
          valign = "top";
        }
      ];

      # ── INPUT DE SENHA — estilo terminal ──────────────────
      input-field = [
        {
          size = "280, 42";
          position = "0, -140";
          halign = "center";
          valign = "center";

          # Visual terminal
          outline_thickness = 1;
          outer_color = "rgb(${p.hud1})";
          inner_color = "rgb(${p.bg1})";
          font_color = "rgb(${p.fg0})";
          font_family = font;

          # Placeholder HUD
          placeholder_text = "<span foreground='##${p.fg2}'>[ AUTHENTICATE ]</span>";

          # Feedback visual
          fail_color = "rgb(${p.red})";
          check_color = "rgb(${p.term1})";
          capslock_color = "rgb(${p.yellow})";

          dots_size = 0.28;
          dots_spacing = 0.3;
          dots_center = true;
          dots_rounding = -1;

          # Sem borda arredondada demais — estilo HUD
          rounding = 4;

          fade_on_empty = true;
          hide_input = false;
        }
      ];
    };
  };
}
