# =============================================================================
# Desktop/Hyprland: thin wrapper de multi-monitor
#
# O que é:
# - Importa o módulo HM de monitores e adiciona o restore automático ao autostart.
# - Mantém desktop/hyprland/user.nix limpo.
# =============================================================================
{ lib, config, pkgs, nhModules, ... }:
{
  imports = [
    "${nhModules}/desktop/monitors.nix"
  ];

  config = lib.mkIf (config.wayland.windowManager.hyprland.enable or false) {
    # Disponibiliza o script no ambiente do usuário
    home.packages = [ pkgs.kryonix-monitors ];

    # Restaura o último modo de monitor salvo ao iniciar a sessão.
    wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
      exec-once = kryonix-monitors restore
    '';
  };
}
