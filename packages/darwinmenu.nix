{
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation {
  pname = "darwinmenu";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "lasaczka";
    repo = "darwinmenu";
    rev = "master";
    sha256 = "16cck1xprij4cl59a84x07k9xgk2zpl4v3jhqanwyr59h4h1i80g";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/plasma/plasmoids/org.latgardi.darwinmenu
    cp -r package/* $out/share/plasma/plasmoids/org.latgardi.darwinmenu/
    runHook postInstall
  '';
}
