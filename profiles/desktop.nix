# =============================================================================
# Profile: desktop
# Autor: rag (via AI Maintainer)
#
# O que é:
# - Preset composável para máquinas desktop/workstation.
# - Agrupa um conjunto de features típicas (virtualização, desenvolvimento, opcionalmente gaming).
#
# Por quê:
# - Evita repetir o mesmo bloco `kryonix.features.*` em múltiplos hosts.
# - Mantém hosts finos e expressivos.
#
# Como usar (no host):
#   kryonix.profiles.desktop.enable = true;
#
# Importante:
# - Este profile NÃO escolhe desktop environment.
# - O desktop continua sendo escolhido via `kryonix.desktop.environment`.
# =============================================================================
{ config, lib, ... }:

let
  cfg = config.kryonix.profiles.desktop;

in
{
  imports = [
    ../modules/nixos/boot/silent-boot.nix
  ];

  options.kryonix.profiles.desktop = {
    enable = lib.mkEnableOption "Perfil desktop (virtualização + desenvolvimento + gaming opcional)";

    gaming = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Habilita a feature gaming como parte do perfil desktop";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    kryonix.boot.silent.enable = lib.mkDefault true;
    kryonix.desktop.sddm.theme.preset = lib.mkDefault "kryonix-clean";

    kryonix.features = {
      virtualization.enable = lib.mkDefault true;
      development.enable = lib.mkDefault true;

      # Gaming é opt-in neste profile.
      gaming.enable = lib.mkDefault cfg.gaming.enable;
    };
  };
}
