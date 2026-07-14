{ ... }:

{
  imports = [
    ./hardware/default.nix
    ./runtime/guard.nix
    ./roles/base.nix
    ./roles/node-operational.nix
    ./roles/services.nix
    ./services/boot.nix
    ./services/networking.nix
    ./services/storage.nix
    ./services/monitoring.nix
    ./services/srv-layout.nix
    ./services/login-audit.nix
    ./services/user-groups.nix
    ./services/user-management.nix
    ../themes/console-branding.nix
    ../themes/plymouth/plymouth.nix
  ];
}
