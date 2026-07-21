{ config, lib, ... }:

{
  hardware.enableRedistributableFirmware = lib.mkDefault true;

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Safe on physical hardware: the service is only activated when the virtio
  # guest-agent port exists. In lab VMs this gives us an auditable proof path.
  services.qemuGuest.enable = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
