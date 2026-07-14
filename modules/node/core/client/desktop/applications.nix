{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    firefox
    libreoffice
    vlc
    wl-clipboard
    file
    htop
    neofetch
    kdePackages.konsole
    kdePackages.dolphin
    kdePackages.kate
    kdePackages.ark
    kdePackages.gwenview
  ];
}
