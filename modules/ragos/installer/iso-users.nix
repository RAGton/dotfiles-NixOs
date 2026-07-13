{ pkgs, lib, ... }:

{
  users.mutableUsers = false;

  users.users.root.initialHashedPassword = lib.mkForce null;
  users.users.root.initialPassword = "ragos";

  users.users.ragos = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    initialPassword = "ragos";
    shell = pkgs.bashInteractive;
  };

  users.users.nixos.initialHashedPassword = lib.mkForce "!";

  security.sudo.wheelNeedsPassword = false;
}
