{ config, lib, pkgs, ... }:
let cfg = config.kryonix.home.features.editor; in
{
  options.kryonix.home.features.editor = {
    vscodeInsiders.enable = lib.mkEnableOption "VSCode Insiders";
    neovim.enable = lib.mkEnableOption "Neovim";
    antigravity.enable = lib.mkEnableOption "Antigravity IDE";
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.vscodeInsiders.enable {
      programs.vscode = lib.mkIf (pkgs ? vscode-insiders) {
        enable = true;
        package = pkgs.vscode-insiders;
      };
    })
    (lib.mkIf cfg.neovim.enable {
      programs.neovim.enable = true;
      programs.neovim.defaultEditor = true;
    })
    (lib.mkIf cfg.antigravity.enable {
      # Antigravity é instalado via inputs.antigravity-nix no módulo common;
      # este flag só registra a intenção no install plan.
    })
  ];
}
