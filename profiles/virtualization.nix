# =============================================================================
# Profile: virtualization
# Autor: rag (via AI Maintainer)
#
# O que é:
# - Preset para habilitar stacks de virtualização de forma simplificada.
# =============================================================================
{ config, lib, ... }:

let
  cfg = config.kryonix.profiles.virtualization;
in
{
  options.kryonix.profiles.virtualization = {
    enable = lib.mkEnableOption "Perfil de virtualização";

    libvirt = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Habilita a stack libvirt/KVM/virt-manager.";
    };
  };

  config = lib.mkIf (cfg.enable || cfg.libvirt) {
    kryonix.features.virtualization = {
      enable = true;
      libvirt.enable = lib.mkIf cfg.libvirt true;
      kvm.enable = lib.mkIf cfg.libvirt true;
    };
  };
}
