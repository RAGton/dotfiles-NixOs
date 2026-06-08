# =============================================================================
# desktop/kde/user.nix — Orquestrador KDE Plasma 6 (Home Manager)
#
# Puro roteador de imports, espelhando desktop/hyprland/user.nix. Cada camada é
# declarativa via plasma-manager (programs.plasma.*).
#
#   default.nix        — base da sessão Plasma/Wayland + pacotes
#   launcher.nix       — fuzzel (Wayland-nativo, layer-shell) — resolve foco de teclado
#   theme.nix          — camada visual (BonaFides Dark, blur, transparência, cursor Nordzy,
#                        painel floating-island, Dolphin otimizado)
#   scheme.nix         — color-scheme "Kryonix Dark" opt-in (tokens próprios), sem
#                        remover BonaFides; ativado por kryonix.desktop.kde.theme.colorScheme
#   kvantum.nix        — tema Kvantum BonaFides + QT_QPA_PLATFORMTHEME
#   tiling.nix         — Krohnkite (kwinrc), 10 desktops virtuais, scratchpad, borderless
#   focus.nix          — Foco-segue-mouse + zero focus-stealing (aproxima Hyprland)
#   lockscreen.nix     — KScreenLocker Kryonix (wallpaper, autolock, lock on resume)
#   keymap.nix         — fonte única de verdade dos atalhos (consumida pelo helper)
#   keybinds.nix       — injeção dos atalhos no Plasma (shortcuts/hotkeys/spectacle)
#   keybind-helper.nix — Kryonix Keybind Helper (janela com todos os atalhos)
# =============================================================================
{ ... }:
{
  imports = [
    ./default.nix
    ./launcher.nix
    ./ai-tools.nix
    ./theme.nix
    ./scheme.nix
    ./kvantum.nix
    ./tiling.nix
    ./focus.nix
    ./lockscreen.nix
    ./keybinds.nix
    ./keybind-helper.nix
  ];
}
