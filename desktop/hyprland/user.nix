# =============================================================================
# user.nix — Orquestrador Hyprland (Home Manager) — Fase 4 completa
#
# Puro roteador de imports dividido em camadas:
#   core/     — config compartilhada, não modificar por usuário
#   caelestia/ — integração de shell específico
#   user-vars/ — personalização por usuário (herda core/ sem modificar)
# =============================================================================
{ ... }:
{
  imports = [
    # Bloco 1 — Hyprland config (monitors, rules, keybinds)
    ./core/monitors.nix
    ./core/rules.nix
    ./core/keybinds.nix
    ./core/xdg.nix

    # Shell integration
    ./caelestia/hyprpaper.nix

    # Bloco 3 — Preferências do usuário
    ./user-vars/keybinds.nix
    ./user-vars/theme.nix
    ./user-vars/mime.nix
  ];
}
