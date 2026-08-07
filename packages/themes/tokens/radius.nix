{
  # packages/themes/tokens/radius.nix
  #
  # Cantos arredondados compartilhados. Cada theme escolhe qual usar:
  #
  #   Carbon  (server-grade, industrial) → radius4 default (cantos vivos)
  #   Eclipse (desktop, Apple-like)      → radius12 default (cantos suaves)
  #
  # Disponibilizamos todos pra que surfaces possam misturar (ex: botão radius4
  # sobre card radius12) sem precisar redefinir tokens localmente.

  radiusNone = 0;
  radiusSm = 4;
  radiusMd = 8;
  radiusLg = 12;
  radiusXl = 16;
  radiusFull = 9999; # pill / círculo
}
