{
  lib,
  fetchFromGitHub,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "node-sddm-theme";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "MarianArlt";
    repo = "sddm-sugar-light";
    rev = "19bac00e7bd99e0388d289bdde41bf6644b88772";
    sha256 = "1xymi0xnwskgq0ddpm0vbxk4nwc4azdz5hq3nmkpd8p24js5kmr9";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    themeDir="$out/share/sddm/themes/node-sugar-light"
    mkdir -p "$themeDir"
    cp -r ./* "$themeDir"/

    # Mantemos a base upstream do Sugar Light, mas precisamos preservar a
    # casca visual local do NODE para que o greeter nao volte ao visual
    # generico. O fork e enxuto: Main.qml e SystemButtons.qml continuam
    # compatíveis com os componentes upstream e so aplicam branding/layout.
    rm -f "$themeDir/Background.jpg"
    install -Dm0644 ${./Background.png} "$themeDir/Background.png"
    install -Dm0644 ${./theme.conf} "$themeDir/theme.conf"
    install -Dm0644 ${./metadata.desktop} "$themeDir/metadata.desktop"
    install -Dm0644 ${./Main.qml} "$themeDir/Main.qml"
    install -Dm0644 ${./Components/SystemButtons.qml} "$themeDir/Components/SystemButtons.qml"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Tema SDDM Sugar Light adaptado para o branding do NODE";
    homepage = "https://github.com/MarianArlt/sddm-sugar-light";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}
