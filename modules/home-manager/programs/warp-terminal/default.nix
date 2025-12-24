{ pkgs, lib, ... }:
{
  ############################
  # Warp Terminal
  ############################

  # Pacotes necessários para o Warp Terminal
  home.packages = with pkgs; [
    warp-terminal
    nerd-fonts.meslo-lg
  ];

  ############################
  # Shell padrão (Warp respeita isso)
  ############################

  programs.zsh = {
    enable = true;

  };

  ############################
  # Fonte (Warp usa Nerd Fonts)
  ############################

  fonts.fontconfig.enable = true;

  # ...existing code...

  ############################
  # Variáveis de ambiente
  ############################

  home.sessionVariables = {
    TERM = "xterm-256color";
  };
}
