{
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "kryonix-branding";
  version = "1.0.0";

  src = ../desktop/branding/kryonix;

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

    cp README.md palette.nix colors.md design-tokens.json "$out/share/kryonix/branding/"
    cp assets/* "$out/share/kryonix/branding/assets/"
    cp wallpapers/* "$out/share/kryonix/branding/wallpapers/"

    cp wallpapers/* "$out/share/backgrounds/kryonix/"
    cp assets/logo.svg assets/mark.svg "$out/share/pixmaps/kryonix/"

    runHook postInstall
  '';

  meta = {
    description = "Camada canônica de branding do Kryonix com paleta, wallpapers, logo e design tokens";
    license = lib.licenses.cc-by-40;
    platforms = lib.platforms.linux;
  };
}
