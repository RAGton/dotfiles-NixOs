# =============================================================================
# core/packages.nix — Ferramentas de sessão Hyprland
#
# Pacotes necessários para os binds de wrappers.nix funcionarem
# mesmo antes de um nixos-rebuild (screenshot, brightness, etc.).
# =============================================================================
{ lib, config, pkgs, ... }:
{
  config = lib.mkIf (config.wayland.windowManager.hyprland.enable or false) {
    home.packages = with pkgs; [
      hyprpicker
      wf-recorder
      libqalculate
      brightnessctl
      kdePackages.ark
    ];
  };
}
