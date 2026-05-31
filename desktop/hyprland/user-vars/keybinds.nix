# =============================================================================
# user-vars/keybinds.nix — Overrides de keybind por usuário (mkOrder:800)
#
# Carrega os wrappers de sessão (scripts de shell para os binds) e serve
# como ponto de override de keybinds específicos deste usuário.
#
# core/keybinds.nix define os binds base em mkOrder:700.
# Qualquer bind adicionado aqui com mkOrder:800 vem depois — use para
# sobrescrever ou acrescentar binds sem modificar o core compartilhado.
# =============================================================================
{ lib, config, ... }:
{
  imports = [
    ../wrappers.nix
  ];

  # Ponto de override: adicione binds específicos do usuário abaixo.
  # Exemplo:
  #   config = lib.mkIf (config.wayland.windowManager.hyprland.enable or false) {
  #     wayland.windowManager.hyprland.extraConfig = lib.mkOrder 800 ''
  #       bind = $mainMod SHIFT, W, exec, wl-mirror DP-1
  #     '';
  #   };
}
