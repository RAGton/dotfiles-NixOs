{ pkgs, lib, ... }:

{
  users.mutableUsers = false;

  users.users.root.initialHashedPassword = lib.mkForce null;
  users.users.root.initialPassword = "node";

  users.users.node = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    initialPassword = "node";
    shell = pkgs.bashInteractive;
  };

  users.users.nixos.initialHashedPassword = lib.mkForce "!";

  security.sudo.wheelNeedsPassword = false;
}
