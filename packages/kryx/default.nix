{ lib, rustPlatform }:

rustPlatform.buildRustPackage {
  pname = "kryx";
  version = "0.1.0";

  src = ./.;

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  meta = with lib; {
    description = "Kryonix Unified CLI";
    license = licenses.unfree;
    mainProgram = "kryx";
  };
}
