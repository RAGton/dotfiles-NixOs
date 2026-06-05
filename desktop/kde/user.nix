# =============================================================================
# desktop/kde/user.nix — Orquestrador KDE Plasma 6 (Home Manager)
#
# Puro roteador de imports, espelhando desktop/hyprland/user.nix. Cada camada é
# declarativa via plasma-manager (programs.plasma.*).
#
#   default.nix        — base da sessão Plasma/Wayland + pacotes
#   theme.nix          — camada visual (BonaFides Dark, blur, transparência, cursor Nordzy,
#                        painel floating-island, Dolphin otimizado)
#   kvantum.nix        — tema Kvantum BonaFides + QT_QPA_PLATFORMTHEME
#   tiling.nix         — Krohnkite (kwinrc), 10 desktops virtuais, scratchpad, borderless
#   launcher.nix       — Wofi (reuso do módulo HM existente) + integração
#   lockscreen.nix     — KScreenLocker Kryonix (wallpaper, autolock, lock on resume)
#   keymap.nix         — fonte única de verdade dos atalhos (consumida pelo helper)
#   keybinds.nix       — injeção dos atalhos no Plasma (shortcuts/hotkeys/spectacle)
#   keybind-helper.nix — Kryonix Keybind Helper (janela com todos os atalhos)
# =============================================================================
{ ... }:
{
  imports = [
    ./default.nix
    ./ai-tools.nix
    ./theme.nix
    ./kvantum.nix
    ./tiling.nix
    ./launcher.nix
    ./lockscreen.nix
    ./keybinds.nix
    ./keybind-helper.nix
  ];
}
