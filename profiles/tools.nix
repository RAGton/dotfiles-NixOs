# =============================================================================
# Profile: tools
# Autor: rag (via AI Maintainer)
#
# O que é:
# - Toolkit de aplicativos e ferramentas utilitárias.
#
# Por quê:
# - Centraliza a configuração de aplicativos que podem ter múltiplas edições
#   ou formas de entrega (como o VSCode).
# =============================================================================
{ config, lib, userConfig, ... }:

let
  cfg = config.kryonix.profiles.tools;
in
{
  options.kryonix.profiles.tools = {
    enable = lib.mkEnableOption "Perfil de ferramentas e utilitários";

    vscodeInsiders = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Habilita o VSCode Insiders via Home Manager.";
    };
  };

  config = lib.mkIf (cfg.enable || cfg.vscodeInsiders) {
    # Integração com Home Manager para o VSCode
    home-manager.users.${userConfig.name} = lib.mkIf cfg.vscodeInsiders {
      kryonix.vscode = {
        enable = true;
        edition = "insiders";
        delivery = "managed-download"; # Padrão para insiders no nosso repo
      };
    };
  };
}
