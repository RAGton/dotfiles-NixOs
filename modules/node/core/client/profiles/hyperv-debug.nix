{ ... }:

{
  imports = [
    ../base-diskless.nix
    ../hardware/hyperv.nix
    ../desktop/plasma-generic.nix
    ../desktop/applications.nix
  ];

  node.auth.homeAfterLogin.enable = true;
  node.auth.pamMountUserGroups.enable = true;
  node.profile.name = "hyperv-debug";
  node.profile.guest = "hyperv";
  node.profile.bootVerbose = true;
}
