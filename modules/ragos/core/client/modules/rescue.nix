{ pkgs, lib, ... }:

{
  services.displayManager.sddm.enable = lib.mkForce false;
  services.desktopManager.plasma6.enable = lib.mkForce false;
  services.xserver.enable = lib.mkForce false;

  services.openssh.enable = true;
  security.pam.mount.enable = lib.mkForce false;

  boot.plymouth.enable = lib.mkForce false;

  environment.systemPackages = with pkgs; [
    bashInteractive
    curl
    ethtool
    git
    htop
    iproute2
    iputils
    lsof
    nfs-utils
    pciutils
    procps
    strace
    tcpdump
    traceroute
    tmux
    usbutils
    vim
  ];

  systemd.defaultUnit = lib.mkForce "multi-user.target";
  systemd.services."getty@tty1".enable = lib.mkForce true;
}
