# =============================================================================
# desktop/kde/launcher.nix — Launcher do KDE (Home Manager)
#
# O que é:
# - Integra o Wofi como launcher do ambiente KDE, reutilizando o módulo já
#   existente em modules/home-manager/programs/wofi (estilo TokyoNight/Glass,
#   layer-shell — funciona sob KWin Wayland, que implementa wlr-layer-shell).
#
# Por quê:
# - Estética Hyprland/Waybar: o Wofi entrega um menu flutuante translúcido,
#   coerente com a "ilha" do painel, em vez do visual do Albert.
# - Reuso: o módulo do Wofi é DE-agnóstico. O atalho (Meta+A) é definido em
#   keybinds.nix via hotkeys.commands.
#
# Nota:
# - O pacote Albert ainda é instalado pelo módulo `common` (HM compartilhado);
#   aqui apenas deixamos de bindá-lo. Para removê-lo por completo seria preciso
#   editar modules/home-manager/common (afeta também a stack Hyprland).
#
# Como:
# - `nhModules` é injetado por extraSpecialArgs (= ${kryonix}/modules/home-manager).
# =============================================================================
{ nhModules, ... }:
{
  imports = [
    "${nhModules}/programs/wofi"
  ];
}
