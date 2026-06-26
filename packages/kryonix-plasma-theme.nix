{
  kryonixBranding,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "kryonix-plasma-theme";
  version = "1.0.0";

  src = ../desktop/kde/kryonix-blue-glass;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -dm755 \
      "$out/share/plasma/desktoptheme" \
      "$out/share/color-schemes" \
      "$out/share/wallpapers/kryonix-blue-glass" \
      "$out/share/kryonix/mascot"

    cp -r desktoptheme/kryonix-blue-glass "$out/share/plasma/desktoptheme/"
    cp color-schemes/*.colors "$out/share/color-schemes/"
    cp mascot/* "$out/share/kryonix/mascot/"
    cp ${kryonixBranding}/share/backgrounds/kryonix/kryonix-blue-glass-dark.svg \
      "$out/share/wallpapers/kryonix-blue-glass/"
    cp ${kryonixBranding}/share/backgrounds/kryonix/kryonix-blue-glass-light.svg \
      "$out/share/wallpapers/kryonix-blue-glass/"

    runHook postInstall
  '';

  meta = {
    description = "Tema Plasma 6 Kryonix Blue Glass com desktoptheme, color schemes e wallpapers";
    license = lib.licenses.cc-by-40;
    platforms = lib.platforms.linux;
  };
}
