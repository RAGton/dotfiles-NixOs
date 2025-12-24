{ config, lib, pkgs, ... }:

with lib;

{
  ############################
  # Libvirt / KVM
  ############################

  virtualisation.libvirtd = {
    enable = true;

    qemu = {
      package = pkgs.qemu_kvm;
      swtpm.enable = true;
      # OVMF já é fornecido automaticamente pelo NixOS atual
    };
  };

  ############################
  # SPICE
  ############################

  virtualisation.spiceUSBRedirection.enable = true;

  ############################
  # Pacotes
  ############################

  environment.systemPackages = with pkgs; [
    qemu
    virt-manager
    virt-viewer
    virtiofsd
    spice-gtk
    spice-protocol
  ];

  ############################
  # Usuário
  ############################

  users.users.rag.extraGroups = [
    "libvirtd"
    "kvm"
  ];

  ############################
  # Polkit
  ############################

  security.polkit.enable = true;

  ############################
  # Libvirt URI padrão
  ############################

  environment.variables = {
    LIBVIRT_DEFAULT_URI = "qemu:///system";
  };
}
