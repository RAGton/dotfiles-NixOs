{ lib, stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "plymouth-theme-ragos";
  version = "1.0.0";

  src = ./.;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    themeDir="$out/share/plymouth/themes/ragos"
    mkdir -p "$themeDir/frames"

    backgroundAsset=""
    if [[ -f background.png ]]; then
      backgroundAsset="background.png"
    elif [[ -f background.jpg ]]; then
      backgroundAsset="background.jpg"
    elif [[ -f source-background.jpg ]]; then
      backgroundAsset="source-background.jpg"
    else
      echo "plymouth-theme-ragos: missing background asset (expected background.png, background.jpg or source-background.jpg)" >&2
      exit 1
    fi

    install -Dm0644 ragos.plymouth "$themeDir/ragos.plymouth"
    install -Dm0644 ragos.script "$themeDir/ragos.script"
    install -Dm0644 "$backgroundAsset" "$themeDir/$backgroundAsset"
    install -Dm0644 logo.png "$themeDir/logo.png"
    install -Dm0644 progress-track.png "$themeDir/progress-track.png"
    install -Dm0644 progress-fill.png "$themeDir/progress-fill.png"
    install -Dm0644 README.md "$themeDir/README.md"
    cp -r frames/. "$themeDir/frames/"

    lastFrame="$(find "$themeDir/frames" -maxdepth 1 -type f -name 'frame-*.png' | sort | tail -n 1)"
    if [[ -n "$lastFrame" ]]; then
      for frame in $(seq -w 1 12); do
        target="$themeDir/frames/frame-$frame.png"
        if [[ ! -f "$target" ]]; then
          cp "$lastFrame" "$target"
        fi
      done
    fi

    substituteInPlace "$themeDir/ragos.plymouth" \
      --replace-fail "@PLYMOUTH_THEME_DIR@" "$themeDir"
    substituteInPlace "$themeDir/ragos.script" \
      --replace-fail 'Image("background.png")' "Image(\"$backgroundAsset\")"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Tema Plymouth autoral do RAGOS para boot netboot";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}
