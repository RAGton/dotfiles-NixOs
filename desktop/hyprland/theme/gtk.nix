{ pkgs, lib, ... }:
{
  gtk = {
    enable = true;

    theme = {
      name    = lib.mkForce "adw-gtk3-dark";
      package = lib.mkForce pkgs.adw-gtk3;
    };

    iconTheme = {
      name    = lib.mkForce "Papirus-Dark";
      package = lib.mkForce pkgs.papirus-icon-theme;
    };

    cursorTheme = {
      name    = lib.mkForce "Bibata-Modern-Ice";   # cursor branco/ciano — combina com HUD
      package = lib.mkForce pkgs.bibata-cursors;
      size    = lib.mkForce 24;
    };

    font = {
      name    = lib.mkForce "CaskaydiaCove Nerd Font";
      size    = lib.mkForce 11;
    };
  };

  qt = {
    enable = true;
    platformTheme.name = lib.mkForce "gtk";
    style.name = lib.mkForce "adwaita-dark";
  };

  # Variáveis de ambiente para cursor e escala
  home.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "24";
    GTK_THEME = "adw-gtk3-dark";
  };
}
