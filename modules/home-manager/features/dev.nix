{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kryonix.home.features.dev;
in
{
  options.kryonix.home.features.dev = {
    git.enable = lib.mkEnableOption "Git tools";
    githubCli.enable = lib.mkEnableOption "GitHub CLI";
    nix.enable = lib.mkEnableOption "Nix development tools";
    rust.enable = lib.mkEnableOption "Rust toolchain";
    python.enable = lib.mkEnableOption "Python environment";
    nodejs.enable = lib.mkEnableOption "Node.js";
    jupyter.enable = lib.mkEnableOption "Jupyter";
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.git.enable {
      programs.git.enable = true;
    })
    (lib.mkIf cfg.githubCli.enable {
      home.packages = with pkgs; [ gh ];
    })
    (lib.mkIf cfg.nix.enable {
      home.packages = with pkgs; [
        nil
        nixfmt-rfc-style
      ];
    })
    (lib.mkIf cfg.rust.enable {
      home.packages = with pkgs; [
        rustup
        cargo
        rustc
        rust-analyzer
      ];
    })
    (lib.mkIf cfg.python.enable {
      home.packages = with pkgs; [
        python3
        uv
        ruff
      ];
    })
    (lib.mkIf cfg.nodejs.enable {
      home.packages = with pkgs; [ nodejs_22 ];
    })
    (lib.mkIf cfg.jupyter.enable {
      programs.jupyter.enable = true;
    })
  ];
}
