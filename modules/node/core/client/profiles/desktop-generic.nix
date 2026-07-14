{ lib, ... }:

{
  imports = [
    ../base-diskless.nix
    ../hardware/physical-generic.nix
    ../desktop/plasma-generic.nix
    ../desktop/applications.nix
    ../desktop/login-welcome.nix
  ];

  node.auth.homeAfterLogin.enable = true;
  node.auth.pamMountUserGroups.enable = true;
  node.profile.name = lib.mkDefault "desktop-generic";
  node.profile.guest = "physical";
  node.profile.bootVerbose = false;

  services.pipewire = {
    enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
    wireplumber.enable = lib.mkDefault true;
  };

  services.printing.enable = lib.mkDefault true;
  services.udisks2.enable = lib.mkDefault true;
}
