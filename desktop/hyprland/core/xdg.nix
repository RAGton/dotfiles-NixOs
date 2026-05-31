# =============================================================================
# core/xdg.nix — Configurações XDG não-condicionais
#
# kdeglobals: comportamento de clique único desabilitado + thumbs remotos off.
# Aplicado sem condicional de shell — vale para todos os backends.
# =============================================================================
{ lib, config, ... }:
{
  config = lib.mkIf (config.wayland.windowManager.hyprland.enable or false) {
    xdg.configFile."kdeglobals".text = ''
      [KDE]
      SingleClick=false

      [PreviewSettings]
      EnableRemoteFolderThumbnail=false
      MaximumRemoteSize=0
    '';
  };
}
