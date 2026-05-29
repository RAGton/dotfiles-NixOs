{ rustPlatform, lib, buildNpmPackage, makeWrapper }:

let
  ui = buildNpmPackage {
    pname = "kryonix-installer-ui-web";
    version = "0.1.0";
    src = ./kryonix-installer/ui;
    
    # Run a dummy build to get the real hash later, or use fakeHash
    npmDepsHash = "sha256-poEo6CdDKcXl7CyB+g32UpdpN/pJJ8GDXGsZrlA4vwc=";
    
    installPhase = ''
      mkdir -p $out/dist
      cp -r static/* $out/dist/
    '';
  };
in
rustPlatform.buildRustPackage {
  pname = "kryonix-installer";
  version = "0.1.0";

  src = ./kryonix-installer;

  cargoLock = {
    lockFile = ./kryonix-installer/Cargo.lock;
  };

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    mkdir -p $out/share/kryonix-installer/ui
    cp -r ${ui}/dist $out/share/kryonix-installer/ui/dist

    wrapProgram $out/bin/kryonix-installer \
      --set RUST_LOG info
  '';

  meta = with lib; {
    description = "Kryonix installer backend (Axum)";
    homepage = "https://github.com/RAGton/kryonix";
    license = lib.licenses.unfree;
    maintainers = [ ];
  };
}
