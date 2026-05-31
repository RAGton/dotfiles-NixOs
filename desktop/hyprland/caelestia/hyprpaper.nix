# =============================================================================
# caelestia/hyprpaper.nix — Wallpaper fallback (sem shell backend)
#
# Cria hyprpaper.conf apenas quando nenhum shell backend está ativo.
# Quando caelestia (ou outro shell) está ativo, ele gerencia o wallpaper
# via seu próprio mecanismo (state file / quickshell) e este módulo é skipped.
# =============================================================================
{ lib, config, ... }:
{
  config = lib.mkIf ((config.kryonix.shell.backend or null) == null) {
    xdg.configFile."hypr/hyprpaper.conf".text = ''
      splash = false
      preload = ${config.wallpaper}
      wallpaper = , ${config.wallpaper}
    '';
  };
}
