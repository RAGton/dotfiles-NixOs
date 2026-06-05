# ==============================================================================
# Módulo: services (serviços UX do desktop)
# Autor: Gabriel Rocha (rag) + Codex
# Data: 2026-03-12
#
# O que é:
# - Serviços/pacotes de suporte para sessão Hyprland + shell Wayland do projeto.
#
# Por quê:
# - Garante lock/logout/notificações/clipboard/screenshot consistentes em todos
#   os hosts sem depender de desktop environments alternativos.
# ==============================================================================
{ pkgs, ... }:
{
  imports = [
    ./tailscale
    ./snapper
    ./tlp
    ./brain.nix
    ./aura.nix
    ./neo4j.nix
    ./llama-cpp.nix
    ./kryonix-state.nix
    ./n8n
    ./home-assistant
  ];

  services.udisks2.enable = true;
  services.gvfs.enable = true;

  environment.systemPackages = with pkgs; [
    hyprlock
    wlogout
    swaynotificationcenter
    swaybg
    cliphist
    grim
    slurp
    swappy
    wl-clipboard
    rofi
  ];
}
