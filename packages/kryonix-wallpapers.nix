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
#   workspace.wallpaper = "${pkgs.kryonix-wallpapers}/share/wallpapers/kryonix-aurora/kryonix-dark-4k.png";
# =============================================================================
{ stdenvNoCC, kryonixAssets, ... }:
stdenvNoCC.mkDerivation {
  pname = "kryonix-wallpapers";
  version = "1.0.0";

  src = "${kryonixAssets}/share/kryonix/assets/wallpapers";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -dm755 "$out/share/wallpapers/kryonix-aurora"

    # Wallpapers from Kryonix Assets
    cp -r ${kryonixAssets}/share/kryonix/assets/wallpapers/*.png "$out/share/wallpapers/kryonix-aurora/"

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
