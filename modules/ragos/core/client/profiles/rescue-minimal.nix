{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/netboot/netboot-minimal.nix")
    ../base-rescue.nix
    ../hardware/physical-generic.nix
    ../modules/rescue.nix
  ];

  ragos.profile.name = lib.mkForce "rescue-minimal";
  ragos.profile.guest = "physical";
  ragos.profile.bootVerbose = true;
  ragos.boot.publishInitrdPath = "${config.system.build.netbootRamdisk}/initrd";
}
