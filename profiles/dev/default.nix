# ==============================================================================
# Profile: dev
# Autor: Gabriel Rocha (rag) + Codex
# Data: 2026-03-12
#
# O que é:
# - Pacotes-base para fluxo de desenvolvimento diário.
# ==============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kryonix.profiles.dev;
in
{
  options.kryonix.profiles.dev = {
    enable = lib.mkEnableOption "Perfil de desenvolvimento";

    enableRust = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Habilita o toolchain Rust via feature development.";
    };

    enableCpp = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Habilita o toolchain C/C++ via feature development.";
    };

    enableJupyter = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Habilita o ambiente Jupyter via programs.jupyter.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ferramentas de base no sistema
    environment.systemPackages = with pkgs; [
      git
      gh
      lazygit
      tmux
      podman
      docker-compose
      docker-client
      neovim
    ];

    # Acoplamento com features
    kryonix.features.development = {
      enable = lib.mkDefault true;
      languages = {
        rust.enable = lib.mkIf cfg.enableRust (lib.mkDefault true);
        c.enable = lib.mkIf cfg.enableCpp (lib.mkDefault true);
      };
    };

    # Acoplamento com programas
    programs.jupyter = lib.mkIf cfg.enableJupyter {
      enable = lib.mkDefault true;
      kernels = {
        rust = lib.mkIf cfg.enableRust (lib.mkDefault true);
        cpp = lib.mkIf cfg.enableCpp (lib.mkDefault true);
      };
    };
  };
}
