{ ... }:

{
  imports = [
    ../base-diskless.nix
    ../hardware/hyperv.nix
    ../desktop/plasma-generic.nix
    ../desktop/applications.nix
  ];

  ragos.auth.homeAfterLogin.enable = true;
  ragos.auth.pamMountUserGroups.enable = true;
  ragos.profile.name = "hyperv-debug";
  ragos.profile.guest = "hyperv";
  ragos.profile.bootVerbose = true;
}
