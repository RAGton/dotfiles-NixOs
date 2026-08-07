# packages/themes/tokens/default.nix
#
# Aggregator dos tokens compartilhados do design system Kryonix.
# Consumido por todos os themes (kryonix-carbon, kryonix-eclipse, ...).
#
# Uso em um theme:
#
#   { pkgs, ... }:
#   let tokens = pkgs.callPackage ../tokens { }; in
#   {
#     theme = {
#       accent = "#FF9F0A";
#       radiusDefault = tokens.radius.radiusSm;  # Carbon
#       spacing = tokens.spacing;
#       # ...
#     };
#   }

{ ... }:

{
  palette = import ./palette-base.nix;
  typography = import ./typography.nix;
  spacing = import ./spacing.nix;
  radius = import ./radius.nix;
}
