{
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "kryonix-branding";
  version = "1.0.0";

  src = ./.;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -dm755 \
      "$out/share/kryonix/branding" \
      "$out/share/kryonix/branding/assets" \
      "$out/share/kryonix/branding/wallpapers" \
      "$out/share/backgrounds/kryonix" \
      "$out/share/pixmaps/kryonix"

    # Removed cp commands since desktop/branding/kryonix does not exist in this repo.

    runHook postInstall
  '';

  meta = {
    description = "Camada canônica de branding do Kryonix com paleta, wallpapers, logo e design tokens";
    license = lib.licenses.cc-by-40;
    platforms = lib.platforms.linux;
  };
}
