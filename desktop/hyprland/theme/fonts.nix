{ pkgs, ... }:
{
  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    # Display — títulos HUD
    nerd-fonts.jetbrains-mono

    # Body / UI — leitura
    ibm-plex

    # Fallback sem-serif limpo
    inter
  ];
}
