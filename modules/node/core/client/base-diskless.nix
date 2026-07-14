{ ... }:

{
  imports = [
    ./base.nix
    ./modules/diskless-core.nix
    ./modules/shutdown.nix
    ./auth/home-after-login.nix
    ./auth/pam-mount-user-groups.nix
    ../themes/sddm/sddm.nix
  ];
}
