# =============================================================================
# desktop/kde/kvantum.nix — Estética "Kryonix Glass" (Kvantum / Qt)
#
# O que é:
# - Aplica o tema Kvantum BonaFides (Dark/Azul/Glass) ao Qt, base da estética
#   "Kryonix Glass" (transparência profunda + blur + paleta azul). O blur do KWin
#   já é habilitado em theme.nix.
#
# Como:
# - Instala o motor Kvantum (Qt6) + o pacote `bonafides-theme` (que provê o tema
#   Kvantum, o desktoptheme, os color-schemes, as decorações Aurorae e os
#   wallpapers — ver packages/bonafides-theme.nix) e força o Qt a usar o platform
#   theme/estilo Kvantum via variáveis de sessão.
#
# Notas:
# - QT_QPA_PLATFORMTHEME é definido AQUI (kvantum). Não defina em default.nix
#   para evitar definição dupla da mesma variável.
# - `bonafides-theme` é instalado em home.packages SÓ aqui (ponto único); os
#   demais módulos (theme.nix) referenciam o pacote diretamente via `pkgs`.
# - O nome do tema no kvconfig deve casar com a pasta em share/Kvantum/, que
#   contém <nome>.kvconfig + <nome>.svg: "BonaFides-Dark-Kvantum".
# =============================================================================
{ pkgs, ... }:
{
  home.packages = [
    pkgs.kdePackages.qtstyleplugin-kvantum
    pkgs.bonafides-theme
  ];

  home.sessionVariables = {
    QT_STYLE_OVERRIDE = "kvantum";
    QT_QPA_PLATFORMTHEME = "kvantum";
  };

  xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=BonaFides-Dark-Kvantum
  '';
}
