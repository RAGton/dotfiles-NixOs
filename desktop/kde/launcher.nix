# =============================================================================
# desktop/kde/launcher.nix — Launcher do KDE: fuzzel (Home Manager)
#
# O que é:
# - Launcher de aplicativos declarativo via `programs.fuzzel` (gera
#   ~/.config/fuzzel/fuzzel.ini). Atalho Meta+A definido em keybinds.nix.
#
# Por quê (histórico do inspiron — Plasma 6/Wayland):
# - Wofi (layer-shell GTK) bugava no Plasma 6 → trocamos por rofi.
# - rofi roda via XWayland como JANELA NORMAL, sujeita à política de foco do
#   KWin. Como focus.nix usa FocusPolicy=FocusFollowsMouse, uma janela aberta
#   longe do cursor NÃO recebe foco de teclado — exigia clicar com o mouse.
# - fuzzel é Wayland-NATIVO: usa wlr-layer-shell com keyboard-interactivity
#   EXCLUSIVO, então captura o teclado imediatamente, independente da política
#   de foco do KWin. Resolve a queixa de "não pega o foco direto do teclado".
#
# Estética (Kryonix Glass plano, sem blur):
# - Fundo navy translúcido (#0b1017), cantos arredondados, borda + destaque no
#   accent #38BDF8 (= 56,189,248, mesma cor dos gauges da barra).
# - Fonte Monocraft (texto) + JetBrainsMono Nerd Font (fallback p/ glifos do
#   prompt/ícones; ambas instaladas em modules/nixos/common).
#
# Notas:
# - exit-on-keyboard-focus-loss=false: sob FocusFollowsMouse, mover o mouse
#   para outra janela poderia disparar perda de foco e fechar o launcher antes
#   da hora. Fechamos só com Escape — comportamento previsível.
# - Cores em fuzzel.ini são RRGGBBAA (hex, sem '#').
#
# Rollback: remover ./launcher.nix de user.nix e reverter o atalho em keybinds.nix.
# =============================================================================
{ ... }:
{
  programs.fuzzel = {
    enable = true;

    settings = {
      main = {
        # Texto em Monocraft; glifos (prompt/ícones) via Nerd Font de fallback.
        font = "Monocraft:size=13,JetBrainsMono Nerd Font:size=13";
        dpi-aware = "no";

        # Ícones de aplicativo via tema Breeze Dark (já configurado em theme.nix).
        icons-enabled = true;
        icon-theme = "breeze-dark";

        # Layout/dimensões — "ilha" flutuante coerente com a barra.
        layer = "overlay";
        width = 42;
        lines = 10;
        horizontal-pad = 22;
        vertical-pad = 16;
        inner-pad = 10;
        line-height = 26;

        # Prompt com glifo de busca (Nerd Font U+F002) + busca por nome/keywords.
        # Aspas no valor preservam o espaço final (fuzzel.ini trima sem aspas).
        prompt = "\"  \"";
        fields = "name,generic,keywords";

        # Terminal padrão Kryonix para entradas Terminal=true.
        terminal = "kryonix-terminal";

        # Não fechar ao perder foco de teclado (ver nota sobre FocusFollowsMouse).
        exit-on-keyboard-focus-loss = false;
      };

      # Paleta Kryonix Glass (RRGGBBAA).
      colors = {
        background = "0b1017f0"; # navy ~94% (flat glass, sem blur)
        text = "c0caf5ff";
        prompt = "38bdf8ff"; # accent
        placeholder = "6b7280ff";
        input = "c0caf5ff";
        match = "38bdf8ff"; # substring casada em accent
        selection = "38bdf82e"; # pílula de seleção (accent ~18%)
        selection-text = "ffffffff";
        selection-match = "38bdf8ff";
        border = "38bdf859"; # accent ~35%
      };

      border = {
        width = 2;
        radius = 16;
      };
    };
  };
}
