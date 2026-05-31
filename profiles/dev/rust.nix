# ==============================================================================
# Profile: dev-rust
# Autor: rag (via AI)
# ==============================================================================
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    rustc
    cargo
    rustfmt
    clippy
    rust-analyzer
    rust-bindgen
  ];
}
