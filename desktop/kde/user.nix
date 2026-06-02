# =============================================================================
# desktop/kde/user.nix — Orquestrador KDE Plasma 6 (Home Manager)
#
# Puro roteador de imports, espelhando desktop/hyprland/user.nix. Cada camada é
# declarativa via plasma-manager (programs.plasma.*).
#
#   default.nix        — base da sessão Plasma/Wayland + pacotes
#   theme.nix          — camada visual (Breeze Dark, blur, transparência, cursor Nordzy,
#                        painel superior minimalista, Dolphin otimizado)
#   tiling.nix         — Krohnkite (kwinrc), 10 desktops virtuais, scratchpad, borderless
#   launcher.nix       — Albert (reuso do módulo existente) + integração
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
    ./keybinds.nix
    ./keybind-helper.nix
  ];
}
