{ lib, ... }:

{
  imports = [
    ../base-diskless.nix
    ../hardware/physical-lab.nix
    ../desktop/plasma-lab.nix
    ../desktop/applications.nix
  ];

  ragos.auth.homeAfterLogin.enable = true;
  ragos.auth.pamMountUserGroups.enable = true;
  ragos.profile.name = "desktop-lab";
  ragos.profile.guest = "physical";
  ragos.profile.bootVerbose = true;

  services.pipewire = {
    enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
    wireplumber.enable = lib.mkDefault true;
  };

  services.printing.enable = lib.mkDefault false;
  services.udisks2.enable = lib.mkDefault true;
}
