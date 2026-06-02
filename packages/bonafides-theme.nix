# =============================================================================
# packages/bonafides-theme.nix — Tema BonaFides (Dark/Azul/Glass) para Plasma 6
#
# O que é:
# - Empacota o repositório L4ki/BonaFides-Plasma-Themes como uma derivação Nix,
#   expondo apenas as partes consumidas pela sessão KDE Kryonix:
#     * Kvantum (estilo Qt) ........ share/Kvantum/<tema>
#     * Plasma desktoptheme ........ share/plasma/desktoptheme/<tema>
#     * Esquemas de cor ............ share/color-schemes/*.colors
#     * Decorações Aurorae ......... share/aurorae/themes/<tema>
#
# - Os wallpapers do upstream NÃO são empacotados: a sessão KDE usa o wallpaper
#   padrão do Kryonix (files/wallpaper/12.png), definido em desktop/kde/theme.nix.
#
# Notas (verificado no rev pinado):
# - Os diretórios do upstream contêm ESPAÇOS no nome (ex.: "BonaFides Kvantum
#   Themes/"), por isso todas as cópias usam aspas.
# - Nome do tema Kvantum (pasta + .kvconfig + .svg): "BonaFides-Dark-Kvantum".
# - Nome do desktoptheme (X-KDE-PluginInfo-Name): "BonaFides-Color-Plasma".
# - Decoração Aurorae Plasma 6: "BonaFides-Color-Dark-Aurorae-6".
# =============================================================================
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "bonafides-theme";
  version = "0-unstable-2024-08-13";

  src = fetchFromGitHub {
    owner = "L4ki";
    repo = "BonaFides-Plasma-Themes";
    rev = "97d4fe35e5c6d925b9f723f5411a42880fe41298";
    hash = "sha256-D0HVxhuPr8fvUm/WshApZQm/eZAEYfsD2CVT8+ncWdE=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p \
      "$out/share/Kvantum" \
      "$out/share/plasma/desktoptheme" \
      "$out/share/color-schemes" \
      "$out/share/aurorae/themes"

    # --- Kvantum (todas as variantes; primária: BonaFides-Dark-Kvantum) ------
    cp -r "BonaFides Kvantum Themes/"* "$out/share/Kvantum/"

    # --- Plasma desktoptheme ------------------------------------------------
    cp -r "BonaFides Plasma Themes/"* "$out/share/plasma/desktoptheme/"

    # --- Esquemas de cor ----------------------------------------------------
    cp "BonaFides Color Schemes/"*.colors "$out/share/color-schemes/"

    # --- Decorações de janela (Aurorae 5 e 6) -------------------------------
    cp -r "BonaFides Window Decorations/"* "$out/share/aurorae/themes/"

    runHook postInstall
  '';

  meta = {
    description = "Tema BonaFides (Dark/Azul/Glass) para KDE Plasma: Kvantum, desktoptheme, color-schemes e Aurorae";
    homepage = "https://github.com/L4ki/BonaFides-Plasma-Themes";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
})
