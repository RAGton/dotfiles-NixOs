{ lib, ... }:

{
  # Baseline fisico voltado a commodity mista cabeada.
  # Continua longe de "suporte universal", mas cobre classes recorrentes
  # com risco operacional razoavel para parques heterogeneos modestos.
  boot.initrd.availableKernelModules = [
    "alx"
    "atl1c"
    "atlantic"
    "bnxt_en"
    "e1000e"
    "i40e"
    "ice"
    "igb"
    "igc"
    "ixgbe"
    "r8169"
    "tg3"
    "virtio_pci"
    "virtio_net"
  ];

  hardware.graphics.enable = lib.mkDefault true;
}
