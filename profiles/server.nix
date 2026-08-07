# =============================================================================
# profiles/server.nix
# Autor: Gabriel Aguiar Rocha (RAGton)
#
# O que é:
# - Profile "server" do Kryonix: workstation dev, headless ops, infra.
# - DEFAULT theme: kryonix-carbon (âmbar Kryonix, server-grade).
#
# Por quê:
# - O Carbon é o "safe default" server-grade: âmbar sobre preto profundo,
#   sem translucência, sem animações decorativas, radius 4 (cantos vivos).
# - Eclipse (azul, Apple-like) fica para profile desktop (futuro).
#
# Como usar:
#   { kryonix.profiles.server.enable = true; }       # Carbon default
#   { kryonix.profiles.server.enable = true;
#     kryonix.profiles.server.theme  = "kryonix-carbon"; }   # explícito
#
# Risco:
# - Esta opção NÃO instala Plasma; ela apenas injeta o pacote do theme
#   em environment.packages e configura Plasma via plasma-manager (HM)
#   quando `kryonix.desktop.environment = "kde"` está ativo.
# - Se Plasma não estiver ativo, o pacote fica disponível mas inerte.
# =============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.kryonix.profiles.server;

  # Themes disponíveis (atualmente apenas carbon).
  # Quando kryonix-eclipse existir, adicionar aqui.
  availableThemes = {
    kryonix-carbon = pkgs.kryonix-carbon;
  };

  # Resolve o theme package; falha explicitamente se nome inválido
  selectedTheme =
    if !hasAttr cfg.theme availableThemes then
      throw ''
        kryonix.profiles.server: theme "${cfg.theme}" não disponível.
        Themes válidos: ${toString (attrNames availableThemes)}
      ''
    else
      availableThemes.${cfg.theme};
in
{
  options.kryonix.profiles.server = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Ativa o profile "server" do Kryonix.

        Inclui o theme default (kryonix-carbon) em environment.packages
        e configura Plasma para usá-lo (quando kryonix.desktop.environment
        = "kde").
      '';
    };

    theme = mkOption {
      type = types.str;
      default = "kryonix-carbon";
      description = ''
        Nome do theme a aplicar neste profile.

        Valores válidos hoje:
          - "kryonix-carbon"  (default, server-grade, âmbar)
      '';
    };
  };

  config = mkIf cfg.enable {
    # Tema sempre instalado quando profile ativo (mesmo sem Plasma)
    environment.packages = [ selectedTheme ];

    # Configuração declarativa do Plasma via plasma-manager (Home Manager)
    # Namespace oficial: programs.plasma.* — confirmado no source upstream
    # (modules/workspace.nix). Ativa SOMENTE se KDE for o DE escolhido
    # E se plasma-manager estiver carregado (fail-safe: mkIf).
    programs.plasma.workspace = mkIf (config.kryonix.desktop.environment or null == "kde") {
      # Color scheme (Plasma 6 .colors filename sem extensão)
      colorScheme = "KryonixCarbon";

      # Plasma desktop style (KPlugin Id do desktoptheme/metadata.json)
      theme = "kryonix-carbon";

      # Look-and-feel global theme (KPlugin Id do look-and-feel/metadata.json)
      lookAndFeel = "KryonixCarbon";
    };

    # Qt/Kvantum: aplicar via env var pro apps Qt não-Plasma
    environment.sessionVariables = mkIf (config.kryonix.desktop.environment or null == "kde") {
      QT_STYLE_OVERRIDE = "kvantum";
      QT_PLUGIN_PATH = "${pkgs.kvantum}/lib/qt-6/plugins";
    };
  };
}
