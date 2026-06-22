# =============================================================================
# packages/kryonix-wallpapers.nix — Pack de wallpapers "Kryonix Aurora"
#
# O que é:
# - Empacota o pack de wallpapers gerados (14 imagens) e o logo SVG da águia
#   em share/wallpapers/kryonix-aurora/ para uso pelo KDE/Home Manager.
#
# Como ativar:
# - Adicionar ao wallpapers list em modules/home-manager/misc/wallpaper/default.nix
#   ou referenciar diretamente em desktop/kde/theme.nix:
#   workspace.wallpaper = "${pkgs.kryonix-wallpapers}/share/wallpapers/kryonix-aurora/kryonix-anime-city-01.png";
# =============================================================================
{ stdenvNoCC, ... }:
stdenvNoCC.mkDerivation {
  pname = "kryonix-wallpapers";
  version = "1.0.0";

  src = ../desktop/wallpapers/kryonix-aurora;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -dm755 "$out/share/wallpapers/kryonix-aurora"

    # Wallpapers processados
    cp -r processed/*.png "$out/share/wallpapers/kryonix-aurora/"

    # Logos e assets
    install -dm755 "$out/share/wallpapers/kryonix-aurora/logos"
    cp logos/*.svg "$out/share/wallpapers/kryonix-aurora/logos/"

    # Manifesto e licença
    install -dm755 "$out/share/wallpapers/kryonix-aurora/sources"
    cp sources/manifest.json "$out/share/wallpapers/kryonix-aurora/sources/"

    runHook postInstall
  '';

  meta = {
    description = "Pack de wallpapers Kryonix Aurora — anime, space e abstract, paleta navy/verde, logo águia";
    license = "CC0-1.0";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
