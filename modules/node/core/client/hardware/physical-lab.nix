{ lib, ... }:

{
  # Baseline estreito para laboratorio previsivel e parque homogêneo.
  # Mantemos um fallback serial explicito so no perfil de lab para prova
  # operacional barata via libvirt, sem mexer no contrato fisico generico.
  boot.kernelParams = [
    "console=tty1"
    "console=ttyS0,115200n8"
  ];

  boot.initrd.availableKernelModules = [
    "e1000e"
    "igc"
    "r8169"
    "tg3"
    "virtio_pci"
    "virtio_net"
  ];

  hardware.graphics.enable = lib.mkDefault true;

  systemd.services."getty@tty1".enable = lib.mkDefault true;
  systemd.services."serial-getty@ttyS0".enable = lib.mkDefault true;
}
