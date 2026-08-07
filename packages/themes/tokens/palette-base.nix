{
  # packages/themes/tokens/palette-base.nix
  #
  # Escala neutra compartilhada entre todos os themes Kryonix.
  # NÃO inclui cor accent — cada theme (Carbon/Eclipse/...) define a sua.
  #
  # Inspiração: IBM Carbon Design System (neutral layer scale).

  bgBase = "#0A0A0A";        # fundo raiz — preto profundo, nunca preto puro
  bgSurface = "#161616";     # superfície padrão (cards, painéis)
  bgElevated = "#1F1F1F";    # superfície elevada (modais, dropdowns, toasts)
  bgOverlay = "#2A2A2A";     # overlay/hover sutil

  fgPrimary = "#F5F5F5";     # texto principal — branco off-white (menos fadiga visual)
  fgSecondary = "#C6C6C6";   # texto secundário
  fgMuted = "#8D8D8D";       # texto terciário, placeholders
  fgInverse = "#161616";     # texto sobre accent

  border = "#393939";        # borda padrão (1px)
  borderSubtle = "#2A2A2A";  # borda sutil (separadores)
  borderStrong = "#525252";  # borda de foco/erro

  selection = "#FF9F0A33";   # overlay accent a 20% para seleção (Carbon: âmbar)

  stateSuccess = "#42BE65";
  stateWarning = "#F1C21B";
  stateError = "#FA4D56";
  stateInfo = "#4589FF";
}