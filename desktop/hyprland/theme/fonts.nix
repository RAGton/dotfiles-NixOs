{ pkgs, ... }:
{
  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    # Display — títulos HUD
    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })

    # Body / UI — leitura
    ibm-plex-mono

    # Fallback sem-serif limpo
    inter
  ];
}
