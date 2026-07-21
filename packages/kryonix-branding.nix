{
  kryonixAssets,
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

    # Create dummy SVGs since the original assets were deleted by the user
    install -dm755 "$out/share/icons/hicolor/scalable/apps"
    cp ${kryonixAssets}/share/kryonix/assets/logos/kryonix-dark.png "$out/share/pixmaps/kryonix/logo.png"
    cp ${kryonixAssets}/share/kryonix/assets/logos/kryonix-dark.png "$out/share/icons/hicolor/scalable/apps/kryonix-logo.png"
    echo '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1920 1080"><rect width="1920" height="1080" fill="#121212"/></svg>' > "$out/share/backgrounds/kryonix/kryonix-clean-dark.svg"
    echo '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1920 1080"><rect width="1920" height="1080" fill="#ffffff"/></svg>' > "$out/share/backgrounds/kryonix/kryonix-clean-light.svg"
    echo '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1920 1080"><rect width="1920" height="1080" fill="#1e1e2e"/></svg>' > "$out/share/backgrounds/kryonix/kryonix-blue-glass-dark.svg"
    echo '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1920 1080"><rect width="1920" height="1080" fill="#eff1f5"/></svg>' > "$out/share/backgrounds/kryonix/kryonix-blue-glass-light.svg"
    runHook postInstall
  '';

  meta = {
    description = "Camada canônica de branding do Kryonix com paleta, wallpapers, logo e design tokens";
    license = lib.licenses.cc-by-40;
    platforms = lib.platforms.linux;
  };
}
