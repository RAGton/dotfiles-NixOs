# =============================================================================
# core/hyprland.nix — Configuração base do WM (Home Manager)
#
# Habilita o Hyprland via HM e aponta para o hyprland.conf versionado.
# CRÍTICO: configType="hyprlang" — não mudar para "lua".
# CRÍTICO: systemd.enable=false — UWSM gerencia a sessão systemd-user.
# =============================================================================
{ lib, ... }:
{
  services.kanshi.enable = lib.mkForce false;

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "hyprlang";
    systemd.enable = false;
    extraConfig = builtins.readFile ../hyprland.conf;
  };
}
