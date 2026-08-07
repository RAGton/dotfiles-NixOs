# =============================================================================
# modules/home-manager/profiles/server.nix
# Autor: Gabriel Aguiar Rocha (RAGton)
#
# O que é:
# - Lado Home Manager do profile "server" (companion de profiles/server.nix).
# - Configura Plasma via plasma-manager (namespace programs.plasma.*) +
#   variáveis Qt/Kvantum pra apps Qt não-Plasma.
#
# Por quê:
# - plasma-manager é um módulo HOME MANAGER (não NixOS). Não pode ser usado
#   em profiles/server.nix (que é NixOS-side). Por isso o split.
#
# Como usar:
#   # No home.nix ou imports do user:
#   imports = [ inputs.kryonix.homeManagerModules.profile-server ];
#
#   # No default.nix do user:
#   programs.plasma.workspace.colorScheme = "KryonixCarbon";  # opcional override
#
# Risco:
# - Sem plasma-manager instalado/configurado, `programs.plasma.*` é ignorado
#   silenciosamente (HM fail-safe).
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
in
{
  config = mkIf (cfg.enable && config.kryonix.desktop.environment or null == "kde") {
    # Plasma 6 desktop config via plasma-manager
    programs.plasma.workspace = {
      # Color scheme (Plasma 6 .colors filename sem extensão)
      colorScheme = "KryonixCarbon";
      # Plasma desktop style (KPlugin Id do desktoptheme/metadata.json)
      theme = "kryonix-carbon";
      # Look-and-feel global theme (KPlugin Id do look-and-feel/metadata.json)
      lookAndFeel = "KryonixCarbon";
    };

    # Qt/Kvantum: aplicar via env var pra apps Qt não-Plasma
    home.sessionVariables = {
      QT_STYLE_OVERRIDE = "kvantum";
      QT_PLUGIN_PATH = "${pkgs.kvantum}/lib/qt-6/plugins";
    };
  };
}
