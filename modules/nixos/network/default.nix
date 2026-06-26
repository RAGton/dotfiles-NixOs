# ==============================================================================
# Módulo: network (NetworkManager UX)
# Autor: Gabriel Rocha (rag) + Codex
# Data: 2026-03-12
#
# O que é:
# - Camada de rede para uso desktop em Hyprland.
#
# Por quê:
# - Mantém conforto de gerenciamento Wi-Fi/VPN equivalente ao ambiente anterior,
#   porém 100% alinhado ao stack Wayland/NM.
# ==============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:
{
  networking.networkmanager.enable = true;
  programs.nm-applet.enable = lib.mkDefault (config.kryonix.desktop.environment != "kde");

  environment.systemPackages =
    with pkgs;
    lib.optional (config.kryonix.desktop.environment != "kde") networkmanagerapplet
    ++ [
      networkmanager_dmenu
      networkmanager
    ];
}
