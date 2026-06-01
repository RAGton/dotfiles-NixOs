# =============================================================================
# desktop/kde/kvantum.nix — Estética "Kryonix Glass" (Kvantum / Qt)
#
# O que é:
# - Aplica o tema Kvantum Catppuccin Mocha (accent azul) ao Qt, base da estética
#   "Kryonix Glass" (transparência profunda + blur + paleta azul). O blur do KWin
#   já é habilitado em theme.nix.
#
# Como:
# - Instala o motor Kvantum (Qt6) + o tema catppuccin-mocha-blue e força o Qt a
#   usar o platform theme/estilo Kvantum via variáveis de sessão.
#
# Nota:
# - QT_QPA_PLATFORMTHEME é definido AQUI (kvantum). Não defina em default.nix
#   para evitar definição dupla da mesma variável.
# =============================================================================
{ pkgs, ... }:
{
  home.packages = [
    pkgs.kdePackages.qtstyleplugin-kvantum
    (pkgs.catppuccin-kvantum.override {
      accent = "blue";
      variant = "mocha";
    })
  ];

  home.sessionVariables = {
    QT_STYLE_OVERRIDE = "kvantum";
    QT_QPA_PLATFORMTHEME = "kvantum";
  };

  xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=catppuccin-mocha-blue
  '';
}
