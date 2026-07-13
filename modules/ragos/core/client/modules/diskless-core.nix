{ ... }:

# ─────────────────────────────────────────────────────────────────────────────
# DISKLESS CORE — orquestrador do boot diskless
#
# Importa os sub-módulos de responsabilidade única:
#   filesystem-diskless.nix  — fileSystems (tmpfs / NFS / overlay)
#   initrd.nix               — boot.initrd (módulos, rede, postDeviceCommands)
#   network.nix              — networking.useDHCP + grub disabled
#
# Não defina aqui configurações que já estejam nos sub-módulos.
# ─────────────────────────────────────────────────────────────────────────────
{
  imports = [
    ./boot/default.nix
  ];
}
