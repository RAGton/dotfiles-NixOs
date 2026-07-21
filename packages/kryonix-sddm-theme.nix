# =============================================================================
# packages/kryonix-sddm-theme.nix — Temas SDDM versionados do Kryonix
#
# O que é:
# - Empacota os temas QML em desktop/sddm/* como derivação única, instalando em
#   share/sddm/themes/<theme-id> (layout que o SDDM espera).
#
# Por quê:
# - Mantém Aurora (legado opt-in) e Clean (novo preset opt-in) versionados no
#   repo, sem depender de download externo nem editor gráfico.
#
# Como ativar:
# - Legado KDE: kryonix.desktop.kde.sddm.theme = "kryonix-aurora";
# - Novo caminho canônico: kryonix.desktop.sddm.theme.preset = "kryonix-clean";
# =============================================================================
{
  kryonixBranding,
  kryonixAssets,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "kryonix-sddm-theme";
  version = "1.1";

  src = ../desktop/sddm;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    themesRoot="$out/share/sddm/themes"
    mkdir -p "$themesRoot"

    for theme in kryonix-aurora kryonix-clean; do
      dest="$themesRoot/$theme"
      mkdir -p "$dest"
      cp -r "$src/$theme/." "$dest/"
    done

    chmod u+w "$themesRoot/kryonix-clean/assets"
    cp ${kryonixAssets}/share/kryonix/assets/logos/kryonix-dark.png \
      "$themesRoot/kryonix-clean/assets/logo.png"
    cp ${kryonixBranding}/share/backgrounds/kryonix/kryonix-clean-dark.svg \
      "$themesRoot/kryonix-clean/assets/background-dark.svg"
    cp ${kryonixBranding}/share/backgrounds/kryonix/kryonix-clean-light.svg \
      "$themesRoot/kryonix-clean/assets/background-light.svg"

    runHook postInstall
  '';

  meta = {
    description = "Temas SDDM do Kryonix: Aurora (legado) e Clean (preset moderno e sobrio)";
    homepage = "https://github.com/RAGton/kryonix";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
