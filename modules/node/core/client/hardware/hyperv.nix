{ config, pkgs, ... }:

let
  hypervHotAddRules = pkgs.writeTextFile {
    name = "hyperv-cpu-and-memory-hotadd-udev-rules";
    destination = "/etc/udev/rules.d/99-hyperv-cpu-and-memory-hotadd.rules";
    text = ''
      SUBSYSTEM=="memory", ACTION=="add", DEVPATH=="/devices/system/memory/memory[0-9]*", TEST=="state", ATTR{state}="online"
      SUBSYSTEM=="cpu", ACTION=="add", DEVPATH=="/devices/system/cpu/cpu[0-9]*", TEST=="online", ATTR{online}="1"
    '';
  };
in
{
  boot.initrd.kernelModules = [
    "hv_balloon"
    "hv_netvsc"
    "hv_storvsc"
    "hv_utils"
    "hv_vmbus"
  ];

  boot.initrd.availableKernelModules = [
    "hyperv_keyboard"
  ];

  boot.kernelModules = [
    "hyperv_fb"
  ];

  boot.kernelParams = [
    "elevator=noop"
  ];

  environment.systemPackages = [
    config.boot.kernelPackages.hyperv-daemons.bin
  ];

  services.udev.packages = [
    hypervHotAddRules
  ];

  systemd.packages = [
    config.boot.kernelPackages.hyperv-daemons.lib
  ];

  systemd.targets.hyperv-daemons.wantedBy = [ "multi-user.target" ];
}
