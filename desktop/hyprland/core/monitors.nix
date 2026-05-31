# =============================================================================
# core/monitors.nix — Configuração de monitores (Hyprland)
#
# Regra genérica: preferred, auto-detect, escala 1.
# Monitores físicos são ajustados por host via kanshi ou overrides de host.
# =============================================================================
{ lib, config, ... }:
{
  config = lib.mkIf (config.wayland.windowManager.hyprland.enable or false) {
    wayland.windowManager.hyprland.extraConfig = lib.mkOrder 100 ''
      monitor=,preferred,auto,1
    '';
  };
}
