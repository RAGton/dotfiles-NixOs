{ ... }:

{
  imports = [
    ./hardware/common-hardware.nix
    ./modules/base.nix
    ./modules/security-no-root.nix
    ./desktop/locale.nix
    ./desktop/keyboard.nix
    ./modules/performance.nix
    ./modules/publish-tree.nix
    ./auth/users.nix
    ../themes/console-branding.nix
    ../themes/plymouth/plymouth.nix
  ];

  system.stateVersion = "25.11";
}
