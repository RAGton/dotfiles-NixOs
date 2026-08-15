# =============================================================================
# packages/macos-tahoe-liquid.nix — Tema Apple "macOS Tahoe Liquid" p/ KDE Plasma 6
#
# O que é:
# - Empacota o upstream lestercorderomurillo/macos-tahoe-liquid-kde v0.47.2 LTS
#   como derivação Nix pura, expondo APENAS assets no Nix Store.
#
# O que NÃO faz (por design):
# - NÃO chama install.sh (que mexe em ~/.local, sudo, configs do usuário).
# - NÃO instala no system profile. Quem decide é o host (opt-in via
#   kryonix.desktop.kde.theme.preset = "tahoe-liquid").
# - NÃO ativa KWin patches automaticamente (ver desktop/kde/tahoe.nix).
#
# Estrutura do upstream (v0.47.2):
#   src/offline/look-and-feel/{MacTahoeLiquidKde-Dark,MacTahoeLiquidKde-Light}
#   src/offline/plasma-theme/{MacTahoeLiquidKde-Dark,MacTahoeLiquidKde-Light}
#   src/offline/color-schemes/MacTahoeLiquidKde{Dark,Light}.colors
#   src/offline/aurorae/{MacTahoeLiquidKde-Dark,MacTahoeLiquidKde-Light}*
#   src/offline/kvantum/mac-tahoe-liquid-kde
#   src/offline/plasmoids/* (6 widgets Apple-style)
#   src/offline/wallpapers/* (15 wallpapers 4K+)
#   src/offline/kwin-effects/acrylic-glass/  → COMPILADO SEPARADO (ver tahoe.nix)
#
# Ativação (opt-in no host):
#   kryonix.desktop.kde.theme.preset = "tahoe-liquid";
#
# Riscos (validados 2026-08-12):
# - R-1: tema é LTS mas autor avisa "Don't use on production yet" no README.
# - R-2: inclui SF Pro (fonte proprietária Apple). Derivação NÃO inclui as
#   fontes (instaladas em runtime via tahoe.nix usando fontes livres como
#   fallback: Inter, Manrope, Source Sans 3).
# - R-3: KWin patch "acrylic-glass" precisa compilação online; não entra nesta
#   derivação. Será empacotado separadamente se Gabriel aprovar Gate 5.
# =============================================================================
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "macos-tahoe-liquid-theme";
  version = "0.47.2";

  src = fetchFromGitHub {
    owner = "lestercorderomurillo";
    repo = "macos-tahoe-liquid-kde";
    rev = "v${finalAttrs.version}";
    # Hash sha256 calculado via nix hash path (2026-08-12).
    # Source: github.com/lestercorderomurillo/macos-tahoe-liquid-kde v0.47.2
    hash = "sha256-oHL1twJrDwfHspiluvF6h5+ur41rkI5XmS3Dvcys7ow=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Pastas de destino (Nix Store padrão share/)
    mkdir -p \
      "$out/share/plasma/look-and-feel" \
      "$out/share/plasma/desktoptheme" \
      "$out/share/color-schemes" \
      "$out/share/aurorae/themes" \
      "$out/share/Kvantum" \
      "$out/share/plasma/plasmoids" \
      "$out/share/wallpapers"

    # Look-and-feel (2 variantes: Dark + Light)
    cp -r "$src/src/offline/look-and-feel/MacTahoeLiquidKde-Dark" \
           "$out/share/plasma/look-and-feel/"
    cp -r "$src/src/offline/look-and-feel/MacTahoeLiquidKde-Light" \
           "$out/share/plasma/look-and-feel/"

    # Plasma desktoptheme (2 variantes)
    cp -r "$src/src/offline/plasma-theme/MacTahoeLiquidKde-Dark" \
           "$out/share/plasma/desktoptheme/"
    cp -r "$src/src/offline/plasma-theme/MacTahoeLiquidKde-Light" \
           "$out/share/plasma/desktoptheme/"

    # Color schemes (2 .colors)
    cp "$src/src/offline/color-schemes/"*.colors "$out/share/color-schemes/"

    # Aurorae window decorations (apenas as pastas dos temas; .desktop e .json
    # ficam na raiz de share/aurorae/themes, mas Plasma lê da pasta).
    cp -r "$src/src/offline/aurorae/MacTahoeLiquidKde-Dark" \
           "$out/share/aurorae/themes/"
    cp -r "$src/src/offline/aurorae/MacTahoeLiquidKde-Light" \
           "$out/share/aurorae/themes/"

    # Kvantum theme (engine Qt)
    mkdir -p "$out/share/Kvantum/mac-tahoe-liquid-kde"
    cp -r "$src/src/offline/kvantum/mac-tahoe-liquid-kde/"* \
           "$out/share/Kvantum/mac-tahoe-liquid-kde/"

    # Plasmoids (Apple-style dock, launcher, global menu, etc)
    for p in "$src/src/offline/plasmoids/"*; do
      cp -r "$p" "$out/share/plasma/plasmoids/"
    done

    # Wallpapers (15 papéis de parede 4K+)
    for w in "$src/src/offline/wallpapers/"*; do
      cp -r "$w" "$out/share/wallpapers/"
    done

    runHook postInstall
  '';

  meta = {
    description = "macOS Tahoe Liquid Glass theme for KDE Plasma 6.6/6.7+ (Apple-style liquid translucency, dock, global menu)";
    homepage = "https://github.com/lestercorderomurillo/macos-tahoe-liquid-kde";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "";
    maintainers = with lib.maintainers; [ ];
  };
})
