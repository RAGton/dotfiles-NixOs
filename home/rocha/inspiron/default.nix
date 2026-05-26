{ lib, pkgs, ... }:
{
  imports = [
    ../../../modules/home-manager/common
    ../../../modules/home-manager/programs/obsidian
    ../../../desktop/hyprland/shell-backend.nix
    ../../../desktop/hyprland/user.nix
    ../../../desktop/hyprland/rice/caelestia-config.nix
    ./caelestia-shell.nix
    ../shared/vscode.nix
  ];

  kryonix.shell.backend = "caelestia";
  kryonix.programs.aiWorkstation.enable = true;
  services.kryonix-brain-tunnel.enable = true;
  services.kryonix-glacier-vnc-tunnel.enable = true;
  services.kryonix-ollama-tunnel.enable = true;

  programs.jupyter = {
    enable = true;
    kernels = {
      python = true;
      c = true;
      rust = true;
      cpp = true;
      bash = true;
      dotnet = false;
      node = false;
    };
  };

  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    atlauncher
    remmina
  ];

}
