# =============================================================================
# desktop/kde/tiling.nix — Tiling (Krohnkite) + desktops virtuais + scratchpad
#
# O que é:
# - Habilita o KWin/Script Krohnkite de forma declarativa e define 10 desktops
#   virtuais nomeados (o 10º é o "Scratchpad").
#
# Por quê:
# - plasma-manager (rev pinada) NÃO tem suporte first-class a Krohnkite — só a
#   "polonium". Por isso usamos o fallback declarativo via kwinrc, conforme
#   autorizado: instala-se o pacote no sistema (modules/nixos/desktop/kde) e
#   habilita-se aqui via `Plugins.krohnkiteEnabled = true`.
#
# Como:
# - kwinrc [Plugins] krohnkiteEnabled=true + ajustes em [Script-krohnkite].
# - kwin.virtualDesktops cria os 10 desktops (escreve kwinrc [Desktops]).
# - borderlessMaximizedWindows melhora a integração com tiling.
# =============================================================================
{ ... }:
{
  programs.plasma = {
    kwin = {
      # Janelas maximizadas sem borda (melhor integração com tiling).
      borderlessMaximizedWindows = true;

      # Convenção Kryonix: 10 desktops virtuais nomeados (0/10 = Scratchpad).
      virtualDesktops = {
        number = 10;
        rows = 2;
        names = [
          "Browser" # 1
          "Terminal" # 2
          "Development" # 3
          "Communication" # 4
          "Infrastructure" # 5
          "AI" # 6
          "Media" # 7
          "VM" # 8
          "Temporary" # 9
          "Scratchpad" # 10 (Meta+S / Meta+Shift+S)
        ];
      };
    };

    # Habilita o Krohnkite (pacote vem do sistema: kdePackages.krohnkite) e
    # ajusta alguns parâmetros de tiling. Chaves desconhecidas são ignoradas
    # pelo KWin, então é seguro manter um conjunto enxuto.
    configFile.kwinrc = {
      Plugins.krohnkiteEnabled = true;
      "Script-krohnkite" = {
        enableColumnsLayout = true;
        screenGapTop = 8;
        screenGapBottom = 8;
        screenGapLeft = 8;
        screenGapRight = 8;
        tileLayoutGap = 8;
      };
    };

    # Remove as barras de título / bordas de TODAS as janelas, requisito do
    # tiling (Krohnkite). Em plasma-manager (rev pinada) a opção correta é
    # `window-rules` (NÃO `kwin.rules`, que não existe): cada regra vira uma
    # seção em kwinrulesrc. Aqui casamos qualquer windowClass por regex e
    # forçamos `noborder = true`.
    window-rules = [
      {
        description = "Kryonix: remover bordas/barras de titulo (tiling Krohnkite)";
        match.window-class = {
          value = ".*";
          type = "regex";
          match-whole = false;
        };
        apply.noborder = {
          value = true;
          apply = "force";
        };
      }
    ];
  };
}
