# =============================================================================
# core/keybinds.nix — Atalhos de teclado/mouse (Hyprland)
#
# Todos via $mainMod = SUPER. Launchers chamam wrappers genéricos do projeto
# (rag-shell-launcher, rag-screenshot, etc.) definidos em wrappers.nix.
# =============================================================================
{ lib, config, ... }:
{
  config = lib.mkIf (config.wayland.windowManager.hyprland.enable or false) {
    wayland.windowManager.hyprland.extraConfig = lib.mkOrder 700 ''
      $mainMod = SUPER

      # --- Janela ---------------------------------------------------------------
      bind = $mainMod, Q, killactive,
      bind = $mainMod, F, togglefloating,
      bind = $mainMod CTRL, M, fullscreen, 0
      bind = $mainMod, Return, layoutmsg, swapwithmaster
      bind = $mainMod, R, layoutmsg, orientationcycle
      bind = $mainMod, Tab, exec, uwsm app -- rag-window-menu
      bind = $mainMod SHIFT, M, movetoworkspacesilent, special
      bind = $mainMod SHIFT, P, togglespecialworkspace
      bind = CTRL ALT, Q, exit

      # Centralizar janela
      bind = CTRL ALT, C, centerwindow

      # --- Foco (hjkl) -----------------------------------------------------------
      bind = $mainMod, h, movefocus, l
      bind = $mainMod, l, movefocus, r
      bind = $mainMod, k, movefocus, u
      bind = $mainMod, j, movefocus, d

      # --- Redimensionar ---------------------------------------------------------
      bind = $mainMod SHIFT, left,  resizeactive, -50 0
      bind = $mainMod SHIFT, right, resizeactive,  50 0
      bind = $mainMod SHIFT, up,    resizeactive,  0 -50
      bind = $mainMod SHIFT, down,  resizeactive,  0  50

      # --- Mouse -----------------------------------------------------------------
      bindm = $mainMod, mouse:272, movewindow
      bindm = $mainMod, mouse:273, resizewindow

      # --- Workspaces ------------------------------------------------------------
      bind = $mainMod, 1, workspace, 1
      bind = $mainMod, 2, workspace, 2
      bind = $mainMod, 3, workspace, 3
      bind = $mainMod, 4, workspace, 4
      bind = $mainMod, 5, workspace, 5
      bind = $mainMod, 6, workspace, 6
      bind = $mainMod, 7, workspace, 7
      bind = $mainMod, 8, workspace, 8
      bind = $mainMod, 9, workspace, 9
      bind = $mainMod, 0, workspace, 10

      bind = $mainMod SHIFT, 1, movetoworkspace, 1
      bind = $mainMod SHIFT, 2, movetoworkspace, 2
      bind = $mainMod SHIFT, 3, movetoworkspace, 3
      bind = $mainMod SHIFT, 4, movetoworkspace, 4
      bind = $mainMod SHIFT, 5, movetoworkspace, 5
      bind = $mainMod SHIFT, 6, movetoworkspace, 6
      bind = $mainMod SHIFT, 7, movetoworkspace, 7
      bind = $mainMod SHIFT, 8, movetoworkspace, 8
      bind = $mainMod SHIFT, 9, movetoworkspace, 9
      bind = $mainMod SHIFT, 0, movetoworkspace, 10

      # Scroll para navegar
      bind = $mainMod, mouse_down, workspace, e+1
      bind = $mainMod, mouse_up,   workspace, e-1

      # --- Apps rápidos ----------------------------------------------------------
      bind = $mainMod, E,          exec, uwsm app -- dolphin
      bind = $mainMod, T,          exec, kryonix-terminal
      bind = $mainMod, C,          exec, uwsm app -- rag-calc-menu
      bind = $mainMod SHIFT, B,    exec, uwsm app -- brave
      bind = $mainMod SHIFT, F,    exec, uwsm app -- dolphin
      bind = $mainMod SHIFT, G,    exec, uwsm app -- codex
      bind = $mainMod CTRL, E,     exec, uwsm app -- filelight

      # --- Launcher / Shell ------------------------------------------------------
      bind = $mainMod, A,        exec, uwsm app -- rag-shell-launcher
      bind = $mainMod, D,        exec, uwsm app -- rag-quick-actions
      bind = $mainMod, G,        exec, uwsm app -- rag-shell-dashboard
      bind = ALT SHIFT, V,       exec, uwsm app -- rag-clipboard-menu
      bind = $mainMod, V,        exec, uwsm app -- rag-clipboard-menu
      bind = $mainMod, N,        exec, rag-shell-notifications

      # --- Utilidades ------------------------------------------------------------
      bind = $mainMod SHIFT, S,        exec, rag-caelestia-ipc picker openFreeze
      bind = $mainMod CTRL,  S,        exec, uwsm app -- rag-screenshot edit-output
      bind = $mainMod SHIFT, R,        exec, $HOME/.local/bin/screen-recorder
      bind = $mainMod CTRL,  R,        exec, uwsm app -- rag-record-menu
      bind = $mainMod, L,              exec, rag-shell-lock
      bind = CTRL ALT, L,              exec, rag-shell-lock
      bind = $mainMod, M,              exec, rag-caelestia-ipc mpris playPause
      bind = $mainMod, X,              exec, uwsm app -- rag-power-menu
      bind = $mainMod, O,              exec, uwsm app -- rag-audio-menu
      bind = $mainMod, W,              exec, uwsm app -- rag-network-menu
      bind = $mainMod SHIFT, C,        exec, hyprpicker -a
      bind = $mainMod SHIFT, Backspace, exec, rag-shell-notifications-clear
      bind = CTRL ALT, P,              exec, gnome-pomodoro --start-stop
      bind = ALT SHIFT, 2,             exec, $HOME/.local/bin/ocr
      bind = $mainMod ALT, W,          exec, ~/.local/bin/kryonix-wallpaper --next
      bind = $mainMod CTRL ALT, W,     exec, ~/.local/bin/kryonix-wallpaper --random

      # --- Multi-monitor ---------------------------------------------------------
      bind = $mainMod, P,             exec, kryonix-monitors menu
      bind = $mainMod ALT, P,         exec, kryonix-monitors mode toggle
      bind = $mainMod, period,        focusmonitor, +1
      bind = $mainMod, comma,         focusmonitor, -1
      bind = $mainMod SHIFT, period,  movewindow, mon:+1
      bind = $mainMod SHIFT, comma,   movewindow, mon:-1
      bind = $mainMod CTRL, period,   movecurrentworkspacetomonitor, +1
      bind = $mainMod CTRL, comma,    movecurrentworkspacetomonitor, -1
      bind = $mainMod ALT, S,         exec, kryonix-monitors swap

      # --- Print Screen ----------------------------------------------------------
      bind = , Print,               exec, uwsm app -- rag-screenshot copy-area
      bind = $mainMod, Print,       exec, uwsm app -- rag-screenshot copysave-screen
      bind = $mainMod SHIFT, Print, exec, uwsm app -- rag-screenshot copysave-active

      # --- Brilho ----------------------------------------------------------------
      bindel = , XF86MonBrightnessUp,        exec, uwsm app -- rag-brightness up
      bindel = , XF86MonBrightnessDown,      exec, uwsm app -- rag-brightness down
      bindel = SHIFT, XF86MonBrightnessUp,   exec, uwsm app -- rag-kbd-brightness up
      bindel = SHIFT, XF86MonBrightnessDown, exec, uwsm app -- rag-kbd-brightness down

      # --- Volume ----------------------------------------------------------------
      bind = , XF86AudioRaiseVolume, exec, pamixer --allow-boost --set-limit 130 --increase 5
      bind = , XF86AudioLowerVolume, exec, pamixer --allow-boost --set-limit 130 --decrease 5
      bind = , XF86AudioMute,        exec, pamixer --toggle-mute
      bind = , XF86AudioMicMute,     exec, pamixer --default-source --toggle-mute
      bind = SHIFT, XF86AudioRaiseVolume, exec, pamixer --increase 5 --default-source
      bind = SHIFT, XF86AudioLowerVolume, exec, pamixer --decrease 5 --default-source
      bind = , XF86AudioPlay,  exec, playerctl play-pause
      bind = , XF86AudioPause, exec, playerctl pause
      bind = , XF86AudioNext,  exec, playerctl next
      bind = , XF86AudioPrev,  exec, playerctl previous
    '';
  };
}
