{
  fetchurl,
  lib,
  p7zip,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "kryonix-waywallen-display-kde";
  version = "0.2.7";

  src = fetchurl {
    url = "https://github.com/waywallen/waywallen-display/releases/download/v0.2.7/waywallen-kde-0.2.7-x86_64-embed.zip";
    hash = "sha256-AzoSFf4qXWP7+H+IvNVC4LR+sSLk57GiQ+sat8U3dEU=";
  };

  nativeBuildInputs = [ p7zip ];

  dontConfigure = true;
  dontBuild = true;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir source
    7z x "$src" -osource >/dev/null
    install -dm755 "$out/share/plasma/plasmoids"
    cp -r source/org.waywallen.kde "$out/share/plasma/plasmoids/"

    runHook postInstall
  '';

  meta = {
    description = "Plasmoid KDE do Waywallen para wallpapers dinamicos no Plasma";
    homepage = "https://github.com/waywallen/waywallen-display";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
