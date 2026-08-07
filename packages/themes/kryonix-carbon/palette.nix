{
  # packages/themes/kryonix-carbon/palette.nix
  #
  # Paleta do theme "Carbon" — server-grade, industrial, hacker.
  # Inspirada no IBM Carbon Design System.
  #
  # Accent: âmbar Kryonix (#FF9F0A) — identidade da distro.
  # Base: escala neutra profunda do palette-base.nix.
  #
  # Targets:
  #   - kryonix.profiles.server.enable = true
  #   - Default se nenhum profile explícito (Carbon é o safe default).

  base = import ../tokens/palette-base.nix;

  # Accent principal (âmbar Kryonix)
  accent = "#FF9F0A";
  accentHover = "#FFB340";
  accentPressed = "#E08E00";
  accentSubtle = "#FF9F0A22";   # ~13% alpha para fills sutis

  # Diferenciação semântica adicional (sobrescreve base quando Carbon)
  terminalBg = "#000000";       # terminal usa preto puro p/ contraste ANSI
  terminalCursor = "#FF9F0A";

  # Cantos e densidade (Carbon é "vivo", industrial)
  radiusDefault = 4;            # radiusSm — não arredonda demais
  density = "compact";          # menos padding, mais info na tela

  # Estados derivados (alinhados com base.stateSuccess/etc; aqui explícitos
  # para casar com a paleta escura do Carbon)
  stateSuccess = "#42BE65";
  stateWarning = "#F1C21B";
  stateError = "#FA4D56";
  stateInfo = "#4589FF";
}