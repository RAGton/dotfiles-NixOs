# =============================================================================
# desktop/kde/focus.nix — Política de foco do KWin (Plasma 6, Home Manager)
#
# O que é:
# - Configura o comportamento de foco do KWin (kwinrc, seção [Windows]) para
#   aproximar a experiência do Hyprland: foco segue o mouse e janelas novas
#   nunca perdem foco para a janela ativa anterior.
#
# Por quê:
# - Default do Plasma 6 é ClickToFocus + FocusStealingPreventionLevel=1, o que
#   causa duas queixas reais no fluxo Kryonix sob tiling Krohnkite:
#     1. Mover o mouse para outra janela não muda o foco — exige clique.
#     2. Programa recém-aberto fica "atrás" e sem foco (focus stealing).
# - Sob WM tiling (Krohnkite), foco-segue-mouse é o esperado, e janelas novas
#   devem entrar ativas no tile recém-criado.
#
# Como:
# - Escreve [Windows] em kwinrc via plasma-manager (configFile.kwinrc).
#   FocusPolicy=FocusFollowsMouse, AutoRaise=false (não levanta janelas
#   cobertas sem ação explícita), FocusStealingPreventionLevel=0 (qualquer
#   janela nova pode pegar foco).
# - tiling.nix toca [Plugins] e [Script-krohnkite] no mesmo configFile.kwinrc;
#   HM mescla atributos sem conflito (sets diferentes).
#
# Notas:
# - DelayFocusInterval e AutoRaiseInterval ficam no default (300ms / 750ms).
#   Se quiser zerar atraso, baixar para 0 em DelayFocusInterval.
# - Aceita também "FocusUnderMouse" / "FocusStrictlyUnderMouse" como variações
#   mais estritas — não usadas por padrão Kryonix.
# =============================================================================
{ ... }:
{
  programs.plasma.configFile.kwinrc.Windows = {
    FocusPolicy = "FocusFollowsMouse";
    AutoRaise = false;
    FocusStealingPreventionLevel = 0;
  };
}
