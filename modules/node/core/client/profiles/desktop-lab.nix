{ lib, ... }:

{
  imports = [
    ../base-diskless.nix
    ../hardware/physical-lab.nix
    ../desktop/plasma-lab.nix
    ../desktop/applications.nix
  ];

  node.auth.homeAfterLogin.enable = true;
  node.auth.pamMountUserGroups.enable = true;
  node.profile.name = "desktop-lab";
  node.profile.guest = "physical";
  node.profile.bootVerbose = true;

  services.pipewire = {
    enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
    wireplumber.enable = lib.mkDefault true;
  };

  services.printing.enable = lib.mkDefault false;
  services.udisks2.enable = lib.mkDefault true;
}
