{ lib
, rustPlatform
, makeWrapper
}:

let
  normalizeText = text: builtins.replaceStrings [ "\r\n" ] [ "\n" ] text;
in
rustPlatform.buildRustPackage {
  pname = "ragos-installer-ui";
  version = "0.1.0";

  src = lib.cleanSource ./.;

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  nativeBuildInputs = [ makeWrapper ];

  postInstall = normalizeText ''
    mkdir -p $out/share/ragos-installer-ui
    cp -r static $out/share/ragos-installer-ui/static
    if [ -d imgs ]; then
      cp -r imgs $out/share/ragos-installer-ui/static/imgs
    fi

    # Garante que o binário encontre assets quando executado fora do repo.
    wrapProgram $out/bin/ragos-installer-ui \
      --set RAGOS_INSTALLER_STATIC $out/share/ragos-installer-ui/static \
      --set RAGOS_INSTALLER_IMGS $out/share/ragos-installer-ui/static/imgs
  '';

  meta = {
    description = "RAGOS Installer UI (Axum)";
    platforms = lib.platforms.linux;
    mainProgram = "ragos-installer-ui";
  };
}
