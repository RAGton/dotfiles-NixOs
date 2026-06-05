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
# - Resolve o caminho do módulo Wofi via `inputs.kryonix` (downstream) ou
#   `inputs.self` (upstream), evitando depender de `nhModules` em
#   extraSpecialArgs — esse arg não chega no caminho NixOS → HM quando o
#   downstream usa hosts/common (que aponta `nhModules` para `inputs.self`,
#   resolvendo no diretório do chamador e não no engine).
# =============================================================================
{ inputs, ... }:
let
  kryonixRoot = inputs.kryonix or inputs.self;
in
{
  imports = [
    "${kryonixRoot}/modules/home-manager/programs/wofi"
  ];
}
