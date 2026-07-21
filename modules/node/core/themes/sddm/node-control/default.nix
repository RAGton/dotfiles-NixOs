{
  lib,
  nodeBrandingAssets ? import ../../../flake/branding-assets.nix,
  stdenvNoCC,
  writeText,
  profileLabel ? "desktop-generic",
  hostLabel ? "node-client",
  transportLabel ? "PXE + HTTP + NFS + NFSv4",
}:

let
  logoTerminalSource = "${nodeBrandingAssets.logoTerminal}";
  themeConf = writeText "node-control-theme.conf" (
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
  pname = "node-sddm-theme";
  version = "2.0.0";

  src = ./.;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    themeDir="$out/share/sddm/themes/node-control"
    mkdir -p "$themeDir/Components"

    install -Dm0644 ${./Main.qml} "$themeDir/Main.qml"
    install -Dm0644 ${./metadata.desktop} "$themeDir/metadata.desktop"
    install -Dm0644 ${themeConf} "$themeDir/theme.conf"
    install -Dm0644 ${./Components/ActionButton.qml} "$themeDir/Components/ActionButton.qml"
    install -Dm0644 ${./Components/InfoChip.qml} "$themeDir/Components/InfoChip.qml"
    install -Dm0644 "${logoTerminalSource}" "$themeDir/Background.png"
    install -Dm0644 "${logoTerminalSource}" "$themeDir/Preview.png"
    install -Dm0644 ${../../plymouth/node/logo.png} "$themeDir/Logo.png"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Tema SDDM NODE Control";
    homepage = "https://github.com/RAGEnterprise/node";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}
