{ lib, ... }:

{
  imports = [
    ../base-diskless.nix
    ../hardware/physical-generic.nix
    ../desktop/plasma-generic.nix
    ../desktop/applications.nix
    ../desktop/login-welcome.nix
  ];

  ragos.auth.homeAfterLogin.enable = true;
  ragos.auth.pamMountUserGroups.enable = true;
  ragos.profile.name = lib.mkDefault "desktop-generic";
  ragos.profile.guest = "physical";
  ragos.profile.bootVerbose = false;

  services.pipewire = {
    enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
    wireplumber.enable = lib.mkDefault true;
  };

  services.printing.enable = lib.mkDefault true;
  services.udisks2.enable = lib.mkDefault true;
}
