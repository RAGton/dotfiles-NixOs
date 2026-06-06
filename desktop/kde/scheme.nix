# =============================================================================
# desktop/kde/scheme.nix — Color-scheme "Kryonix Dark" (opt-in)
#
# O que é:
# - Esquema de cores oficial Kryonix para o KDE Plasma 6, montado a partir dos
#   tokens da identidade visual (background #0B0F14, accent #38BDF8, …). É um
#   color-scheme do Plasma (.colors), gerado declarativamente.
#
# Por quê:
# - O default do host é o esquema azul BonaFides (theme.nix). Este módulo NÃO o
#   substitui: oferece um esquema alternativo, ativado apenas quando o host
#   seleciona `kryonix.desktop.kde.theme.colorScheme = "kryonix-dark"`. BonaFides
#   (lookAndFeel + Kvantum) permanece a base; aqui só trocamos color-scheme + accent.
#
# Como:
# - O arquivo `KryonixDark.colors` é SEMPRE escrito em
#   ~/.local/share/color-schemes/ (fica disponível para seleção manual também).
# - Quando o opt-in está ativo (lib.mkIf), forçamos
#   `programs.plasma.workspace.colorScheme = "KryonixDark"` e o AccentColor
#   correspondente (sobrepõem os valores BonaFides definidos em theme.nix → mkForce).
# - Fallback: com "bonafides" (default), nada é ativado — o .colors fica em disco
#   sem efeito; o esquema BonaFides do theme.nix prevalece. Sem quebra.
#
# `osConfig` é o config do NixOS, disponível no Home Manager integrado
# (home-manager.users.<name>); usamos `or "bonafides"` por robustez.
# =============================================================================
{ lib, osConfig, ... }:
let
  selected = osConfig.kryonix.desktop.kde.theme.colorScheme or "bonafides";
  active = selected == "kryonix-dark";

  # --- Tokens Kryonix (hex → "R,G,B" para o formato .colors) ----------------
  background = "11,15,20"; # #0B0F14
  surface = "17,24,39"; # #111827
  surfaceAlt = "31,41,55"; # #1F2937
  border = "51,65,85"; # #334155
  text = "229,231,235"; # #E5E7EB
  textMuted = "148,163,184"; # #94A3B8
  accent = "56,189,248"; # #38BDF8
  accentStrong = "14,165,233"; # #0EA5E9
  danger = "239,68,68"; # #EF4444
  warning = "245,158,11"; # #F59E0B
  success = "34,197,94"; # #22C55E

  # Bloco de papéis de cor reutilizado pelas seções de superfície
  # (Window/View/Tooltip/Complementary). bg/alt variam por seção.
  roleLines = bg: alt: ''
    BackgroundNormal=${bg}
    BackgroundAlternate=${alt}
    ForegroundNormal=${text}
    ForegroundInactive=${textMuted}
    ForegroundActive=${accent}
    ForegroundLink=${accent}
    ForegroundVisited=${accentStrong}
    ForegroundNegative=${danger}
    ForegroundNeutral=${warning}
    ForegroundPositive=${success}
    DecorationFocus=${accent}
    DecorationHover=${accentStrong}
  '';

  colorsFile = ''
    [General]
    Name=Kryonix Dark
    ColorScheme=KryonixDark
    accentActiveTitlebar=false
    shadeSortColumn=true

    [Colors:Window]
    ${roleLines background surface}

    [Colors:View]
    ${roleLines background surfaceAlt}

    [Colors:Button]
    BackgroundNormal=${surface}
    BackgroundAlternate=${surfaceAlt}
    ForegroundNormal=${text}
    ForegroundInactive=${textMuted}
    ForegroundActive=${accent}
    ForegroundLink=${accent}
    ForegroundVisited=${accentStrong}
    ForegroundNegative=${danger}
    ForegroundNeutral=${warning}
    ForegroundPositive=${success}
    DecorationFocus=${accent}
    DecorationHover=${accentStrong}

    [Colors:Selection]
    BackgroundNormal=${accent}
    BackgroundAlternate=${accentStrong}
    ForegroundNormal=${background}
    ForegroundInactive=${textMuted}
    ForegroundActive=${background}
    ForegroundLink=${background}
    ForegroundVisited=${background}
    ForegroundNegative=${danger}
    ForegroundNeutral=${warning}
    ForegroundPositive=${success}
    DecorationFocus=${accent}
    DecorationHover=${accentStrong}

    [Colors:Tooltip]
    ${roleLines surface surfaceAlt}

    [Colors:Complementary]
    ${roleLines background surface}

    [Colors:Header]
    BackgroundNormal=${surface}
    BackgroundAlternate=${surfaceAlt}
    ForegroundNormal=${text}
    ForegroundInactive=${textMuted}
    ForegroundActive=${accent}
    ForegroundLink=${accent}
    ForegroundVisited=${accentStrong}
    ForegroundNegative=${danger}
    ForegroundNeutral=${warning}
    ForegroundPositive=${success}
    DecorationFocus=${accent}
    DecorationHover=${accentStrong}

    [WM]
    activeBackground=${surface}
    activeForeground=${text}
    inactiveBackground=${background}
    inactiveForeground=${textMuted}
    activeBlend=${accent}
    inactiveBlend=${border}

    [KDE]
    contrast=4
  '';
in
{
  # Sempre disponível em ~/.local/share/color-schemes/ (seleção manual também).
  xdg.dataFile."color-schemes/KryonixDark.colors".text = colorsFile;

  # Ativação opt-in: sobrepõe o esquema/accent BonaFides definidos em theme.nix.
  programs.plasma = lib.mkIf active {
    workspace.colorScheme = lib.mkForce "KryonixDark";
    configFile.kdeglobals.General.AccentColor = lib.mkForce accent;
  };
}
