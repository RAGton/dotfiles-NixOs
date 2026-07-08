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

  # A sessão Plasma/SDDM (Wayland) NÃO carrega hm-session-vars.sh (esse arquivo
  # só é lido por shells de login interativos), então as variáveis acima não
  # chegam ao startplasma e o Kvantum não é aplicado. Entregamos as mesmas vars
  # via script de ambiente da sessão, que o Plasma faz source no boot da sessão
  # (~/.config/plasma-workspace/env/*.sh). É o mecanismo canônico do Plasma.
  xdg.configFile."plasma-workspace/env/kvantum-platformtheme.sh".text = ''
    export QT_QPA_PLATFORMTHEME=kvantum
    export QT_STYLE_OVERRIDE=kvantum
  '';

  xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=WhiteSurDark

    [WhiteSurDark]
    reduce_window_opacity=8
    reduce_menu_opacity=12
  '';
}
