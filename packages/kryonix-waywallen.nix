{
  fetchurl,
  lib,
  makeWrapper,
  p7zip,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "kryonix-waywallen";
  version = "0.2.2";

  src = fetchurl {
    url = "https://github.com/waywallen/waywallen/releases/download/v0.2.2/waywallen-0.2.2-x86_64.AppImage";
    hash = "sha256-HvpTNvPU5Ijn3xls8xWJ09issTdOJlG5sva93qXoAK4=";
  };

  nativeBuildInputs = [
    makeWrapper
    p7zip
  ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/libexec/waywallen"
    7z x "$src" -o"$out/libexec/waywallen" >/dev/null

    chmod +x "$out"/libexec/waywallen/usr/bin/*

    # O plugin open-wallpaper-engine fica separado em pacote opt-in próprio.
    rm -rf "$out/libexec/waywallen/usr/share/waywallen/plugins/org.waywallen.open-wallpaper-engine"
    rm -f "$out/libexec/waywallen/usr/bin/waywallen-wescene-renderer"

    mkdir -p \
      "$out/bin" \
      "$out/share/applications" \
      "$out/share/icons/hicolor/scalable/apps" \
      "$out/share/waywallen"

    cp -r "$out/libexec/waywallen/usr/share/waywallen/." "$out/share/waywallen/"
    cp "$out/libexec/waywallen/usr/share/applications/org.waywallen.waywallen.desktop" \
      "$out/share/applications/"
    cp "$out/libexec/waywallen/usr/share/icons/hicolor/scalable/apps/org.waywallen.waywallen.svg" \
      "$out/share/icons/hicolor/scalable/apps/"

    for bin in waywallen waywallen-ui waywallen-layer-shell waywallen-image-renderer waywallen-video-renderer; do
      makeWrapper "$out/libexec/waywallen/usr/bin/$bin" "$out/bin/$bin" \
        --set LD_LIBRARY_PATH "$out/libexec/waywallen/usr/lib" \
        --set QT_PLUGIN_PATH "$out/libexec/waywallen/usr/plugins" \
        --set QML2_IMPORT_PATH "$out/libexec/waywallen/usr/qml" \
        --set QML_IMPORT_PATH "$out/libexec/waywallen/usr/qml"
    done

    runHook postInstall
  '';

  meta = {
    description = "Waywallen empacotado via release oficial para integracao opt-in de wallpapers dinamicos no Kryonix";
    homepage = "https://github.com/waywallen/waywallen";
    license = lib.licenses.mit;
    mainProgram = "waywallen";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
