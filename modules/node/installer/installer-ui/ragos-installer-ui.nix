{
  lib,
  rustPlatform,
  makeWrapper,
}:

let
  normalizeText = text: builtins.replaceStrings [ "\r\n" ] [ "\n" ] text;
in
rustPlatform.buildRustPackage {
  pname = "node-installer-ui";
  version = "0.1.0";

  src = lib.cleanSource ./.;

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  nativeBuildInputs = [ makeWrapper ];

  postInstall = normalizeText ''
    mkdir -p $out/share/node-installer-ui
    cp -r static $out/share/node-installer-ui/static
    if [ -d imgs ]; then
      cp -r imgs $out/share/node-installer-ui/static/imgs
    fi

    # Garante que o binário encontre assets quando executado fora do repo.
    wrapProgram $out/bin/node-installer-ui \
      --set NODE_INSTALLER_STATIC $out/share/node-installer-ui/static \
      --set NODE_INSTALLER_IMGS $out/share/node-installer-ui/static/imgs
  '';

  meta = {
    description = "NODE Installer UI (Axum)";
    platforms = lib.platforms.linux;
    mainProgram = "node-installer-ui";
  };
}
