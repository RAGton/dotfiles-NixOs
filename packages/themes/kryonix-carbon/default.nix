# packages/themes/kryonix-carbon/default.nix
#
# Derivação Nix para o theme "Kryonix Carbon".
#
# Estrutura do source:
#   plasma/        → color scheme (.colors) + (futuro) desktoptheme
#   kvantum/       → tema Kvantum (kvantum.kvconfig + .svg)
#   aurorae/       → decoração de janelas (Aurorae)
#   splash/        → splash screen (futuro)
#
# Layout de saída (no $out/share/...):
#   $out/share/color-schemes/KryonixCarbon.colors
#   $out/share/Kvantum/KryonixCarbon/
#   $out/share/aurorae/themes/KryonixCarbon/
#   $out/share/splash/themes/KryonixCarbon/   (futuro)
#
# TODO (próximas sprints):
#   - Adicionar plasma/desktoptheme/KryonixCarbon/ (svg panels, widgets)
#   - Adicionar plasma/look-and-feel/ (global theme)
#   - Splash screen SVG em splash/
#   - Wallpaper default alinhado ao accent Carbon
{
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "kryonix-carbon";
  version = "1.0.0";

  # builtins.path com filtro simples (true = inclui tudo).
  # Necessário porque lib.cleanSource em Nix 2.35+ filtra untracked files,
  # quebrando o build enquanto desktoptheme/ e look-and-feel/ ainda não
  # estão commitados.
  src = builtins.path {
    path = ./.;
    name = "kryonix-carbon-source";
    filter = path: type: true;
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Color schemes (Plasma)
    mkdir -p "$out/share/color-schemes"
    cp plasma/*.colors "$out/share/color-schemes/"

    # Plasma desktoptheme (widgets SVGs + metadata)
    mkdir -p "$out/share/plasma/desktoptheme/KryonixCarbon"
    cp -r desktoptheme/KryonixCarbon/. "$out/share/plasma/desktoptheme/KryonixCarbon/"

    # Plasma look-and-feel (global theme) — apply-once metadata
    mkdir -p "$out/share/plasma/look-and-feel/KryonixCarbon/contents"
    cp look-and-feel/metadata.json "$out/share/plasma/look-and-feel/KryonixCarbon/"
    cp look-and-feel/contents/defaults "$out/share/plasma/look-and-feel/KryonixCarbon/contents/"

    # Kvantum (Qt style)
    mkdir -p "$out/share/Kvantum/KryonixCarbon"
    cp -r kvantum/. "$out/share/Kvantum/KryonixCarbon/"

    # Aurorae (window decoration)
    mkdir -p "$out/share/aurorae/themes/KryonixCarbon"
    cp -r aurorae/KryonixCarbon/. "$out/share/aurorae/themes/KryonixCarbon/"

    # Splash (placeholder — preparado pra FASE 3)
    mkdir -p "$out/share/splash/themes/KryonixCarbon"
    if [ -d splash ] && [ "$(ls -A splash 2>/dev/null)" ]; then
      cp -r splash/. "$out/share/splash/themes/KryonixCarbon/"
    fi

    # Metadados do theme (Nix side)
    mkdir -p "$out/share/kryonix/themes/kryonix-carbon"
    cp palette.nix "$out/share/kryonix/themes/kryonix-carbon/palette.nix"

    runHook postInstall
  '';

  meta = {
    description = "Kryonix Carbon — theme server-grade (âmbar Kryonix sobre preto profundo), tokens compartilhados, Plasma/Kvantum/Aurorae";
    longDescription = ''
      Theme Carbon é o default server-grade do design system Kryonix.
      Inspirado no IBM Carbon Design System, mantém performance em
      ambientes headless e workstation dev: sem translucência, sem
      animações decorativas, cantos vivos (radius 4).
    '';
    license = lib.licenses.cc-by-40;
    platforms = lib.platforms.linux;
    maintainers = [ ];
  };
}
