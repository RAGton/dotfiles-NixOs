{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kryonix.home.features.shell;
in
{
  options.kryonix.home.features.shell = {
    zsh.enable = lib.mkEnableOption "ZSH with Oh My Zsh";
    starship.enable = lib.mkEnableOption "Starship prompt";
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.zsh.enable {
      programs.zsh.enable = true;
      programs.zsh.oh-my-zsh = {
        enable = true;
        theme = "robbyrussell";
        plugins = [
          "git"
          "sudo"
        ];
      };
    })
    (lib.mkIf cfg.starship.enable {
      programs.starship.enable = true;
    })
  ];
}
