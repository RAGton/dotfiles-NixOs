{
  # packages/themes/tokens/typography.nix
  #
  # Tokens tipográficos compartilhados.
  # Inter é a família padrão do ecossistema Kryonix (UI + desktop + docs).

  fontFamily = "Inter, 'Inter Variable', 'Helvetica Neue', sans-serif";
  fontFamilyMono = "'JetBrains Mono', 'Fira Code', 'Inter', monospace";

  weightRegular = 400;
  weightMedium = 500;
  weightSemibold = 600;

  sizeXs = 11; # micro / caption
  sizeSm = 12; # small / label
  sizeBase = 14; # body default
  sizeMd = 16; # sub-título
  sizeLg = 20; # título
  sizeXl = 28; # título de página
  size2xl = 36; # display

  lineHeightTight = 1.2;
  lineHeightNormal = 1.45;
  lineHeightLoose = 1.6;
}
