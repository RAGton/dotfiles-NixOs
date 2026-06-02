# =============================================================================
# packages/kryonix-bar/default.nix — Backend D-Bus da Kryonix Bar (Rust)
#
# Empacota o crate em ./backend como derivação Nix via buildRustPackage. O
# Cargo.lock é necessário para o build hermético (rode `cargo generate-lockfile`
# em ./backend ao mexer nas dependências).
#
# zbus 4.x usa libsystemd? Não — usa sockets D-Bus diretamente; nenhuma lib de
# sistema extra é necessária aqui além do toolchain Rust.
# =============================================================================
{ lib, rustPlatform }:
rustPlatform.buildRustPackage {
  pname = "kryonix-bar-backend";
  version = "0.1.0";
  src = ./backend;
  cargoLock = {
    lockFile = ./backend/Cargo.lock;
  };

  meta = {
    description = "Backend D-Bus (org.kryonix.Bar) da Kryonix Bar";
    platforms = lib.platforms.linux;
  };
}
