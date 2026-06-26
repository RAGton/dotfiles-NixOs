{
  fetchurl,
  lib,
  p7zip,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "kryonix-open-wallpaper-engine";
  version = "0.1.8";

  src = fetchurl {
    url = "https://github.com/waywallen/open-wallpaper-engine/releases/download/v0.1.8/org.waywallen.open-wallpaper-engine-0.1.8-linux-x86_64.zip";
    hash = "sha256-7vYYp76mFBstzC9VC6t46/WNIOvB2ubROyR34Bpewp0=";
  };

  nativeBuildInputs = [ p7zip ];

  dontConfigure = true;
  dontBuild = true;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    pluginRoot="$out/share/waywallen/plugins/org.waywallen.open-wallpaper-engine"
    mkdir source
    7z x "$src" -osource >/dev/null
    install -dm755 "$pluginRoot"
    cp -r source/* "$pluginRoot/"
    chmod +x "$pluginRoot"/bin/waywallen-wescene-renderer
    chmod +x "$pluginRoot"/bin/weweb/chrome-sandbox
    chmod +x "$pluginRoot"/bin/weweb/waywallen-weweb-renderer

    runHook postInstall
  '';

  meta = {
    description = "Plugin open-wallpaper-engine para o Waywallen, com suporte a scene e web wallpapers";
    homepage = "https://github.com/waywallen/open-wallpaper-engine";
    license = lib.licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
