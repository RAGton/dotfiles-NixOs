# =============================================================================
# packages/kryonix-sddm-theme.nix — Tema SDDM "Kryonix Aurora"
#
# O que é:
# - Empacota o tema QML em desktop/sddm/kryonix-aurora/ como derivação,
#   instalando em share/sddm/themes/kryonix-aurora (layout que o SDDM espera).
#
# Por quê:
# - Tema próprio (dark navy, accent #38BDF8), versionado no repo, sem editor
#   gráfico (sddm-config-editor) e sem assets externos baixados da internet —
#   a arte é SVG própria em desktop/sddm/kryonix-aurora/assets/.
#
# Como ativar (opt-in, NÃO troca o default global):
# - kryonix.desktop.kde.sddm.theme = "kryonix-aurora";
#   (módulo modules/nixos/desktop/kde/default.nix adiciona este pacote ao
#    sistema e seta services.displayManager.sddm.theme + qtsvg para o SVG.)
#
# Notas:
# - src é o diretório do tema NO REPO (caminho local), então o conteúdo entra
#   no /nix/store sem fetch externo. Para o build via flake (git+file) enxergar
#   os arquivos, eles precisam estar tracked pelo git.
# - O greeter usa Qt6 (Plasma 6); o SVG via Image requer o plugin qtsvg,
#   injetado por sddm.extraPackages no módulo.
# =============================================================================
{
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "kryonix-sddm-theme";
  version = "1.0";

  src = ../desktop/sddm/kryonix-aurora;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    dest="$out/share/sddm/themes/kryonix-aurora"
    mkdir -p "$dest"
    cp -r "$src/." "$dest/"

    runHook postInstall
  '';

  meta = {
    description = "Tema SDDM Kryonix Aurora — dark navy, accent #38BDF8, QtQuick (sem assets externos)";
    homepage = "https://github.com/RAGton/kryonix";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
