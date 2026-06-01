# =============================================================================
# desktop/kde/launcher.nix — Albert no KDE (Home Manager)
#
# O que é:
# - Integra o Albert como launcher do ambiente KDE, reutilizando o módulo já
#   existente em modules/home-manager/programs/albert (instala pacote + config +
#   systemd-user service com WantedBy graphical-session.target).
#
# Por quê:
# - Evita duplicação: o módulo do Albert é DE-agnóstico. Os atalhos (Meta+A,
#   Meta+Shift+A, Meta+Ctrl+A) são definidos em keybinds.nix via hotkeys.commands.
#
# Como:
# - `nhModules` é injetado por extraSpecialArgs (= ${kryonix}/modules/home-manager).
# =============================================================================
{ nhModules, ... }:
{
  imports = [
    "${nhModules}/programs/albert"
  ];
}
