{
  lib,
  ragosBrandingAssets ? import ../../../flake/branding-assets.nix,
  stdenvNoCC,
  writeText,
  profileLabel ? "desktop-generic",
  hostLabel ? "ragos-client",
  transportLabel ? "PXE + HTTP + NFS + NFSv4",
}:

let
  logoTerminalSource = "${ragosBrandingAssets.logoTerminal}";
  themeConf = writeText "ragos-control-theme.conf" (
    builtins.replaceStrings
      [
        "@profileLabel@"
        "@hostLabel@"
        "@transportLabel@"
      ]
      [
        profileLabel
        hostLabel
        transportLabel
      ]
      (builtins.readFile ./theme.conf.in)
  );
in
stdenvNoCC.mkDerivation {
  pname = "ragos-sddm-theme";
  version = "2.0.0";

  src = ./.;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    themeDir="$out/share/sddm/themes/ragos-control"
    mkdir -p "$themeDir/Components"

    install -Dm0644 ${./Main.qml} "$themeDir/Main.qml"
    install -Dm0644 ${./metadata.desktop} "$themeDir/metadata.desktop"
    install -Dm0644 ${themeConf} "$themeDir/theme.conf"
    install -Dm0644 ${./Components/ActionButton.qml} "$themeDir/Components/ActionButton.qml"
    install -Dm0644 ${./Components/InfoChip.qml} "$themeDir/Components/InfoChip.qml"
    install -Dm0644 "${logoTerminalSource}" "$themeDir/Background.png"
    install -Dm0644 "${logoTerminalSource}" "$themeDir/Preview.png"
    install -Dm0644 ${../../plymouth/ragos/logo.png} "$themeDir/Logo.png"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Tema SDDM RAGOS Control";
    homepage = "https://github.com/RAGEnterprise/ragos";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}
