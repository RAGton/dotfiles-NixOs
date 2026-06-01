{
  rustPlatform,
  lib,
  buildNpmPackage,
  makeWrapper,
  pkg-config,
  openssl,
}:

let
  ui = buildNpmPackage {
    pname = "kryonix-installer-ui-web";
    version = "0.1.0";
    src = ./kryonix-installer/ui;

    # Run a dummy build to get the real hash later, or use fakeHash
    npmDepsHash = "sha256-sUEtL5G0JMBVcaDwk7YTI5VaaGBsziQ9FuMuXN14BUw=";

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

  nativeBuildInputs = [
    makeWrapper
    pkg-config
  ];
  buildInputs = [ openssl ];

  # reqwest with rustls-tls links against openssl for the host build
  OPENSSL_NO_VENDOR = 1;

  postInstall = ''
    mkdir -p $out/share/kryonix-installer/ui
    cp -r ${ui}/dist $out/share/kryonix-installer/ui/dist

    wrapProgram $out/bin/kryonix-installer \
      --set RUST_LOG info
      # GITHUB_CLIENT_ID must be supplied at runtime by the caller (nixos module or CLI).
      # Intentionally NOT hardcoded here — it is a deployment-time secret.
  '';

  meta = with lib; {
    description = "Kryonix installer backend (Axum)";
    homepage = "https://github.com/RAGton/kryonix";
    license = lib.licenses.unfree;
    maintainers = [ ];
  };
}
