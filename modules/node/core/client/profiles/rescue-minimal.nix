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

  node.profile.name = lib.mkForce "rescue-minimal";
  node.profile.guest = "physical";
  node.profile.bootVerbose = true;
  node.boot.publishInitrdPath = "${config.system.build.netbootRamdisk}/initrd";
}
