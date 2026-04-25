{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  iconThemeName = lib.attrByPath [ "gtk" "iconTheme" "name" ] null config;

  kvantumThemeName = "KvLibadwaitaDark";

  qtCtAppearanceConfig = generators.toINI { } {
    Appearance = {
      icon_theme = if iconThemeName != null then iconThemeName else "Papirus-Dark";
    };
  };

in
{
  home.packages = [
    pkgs.libsForQt5.qtstyleplugin-kvantum
    pkgs.qt6Packages.qtstyleplugin-kvantum
    pkgs.libsForQt5.qt5ct
    pkgs.qt6Packages.qt6ct
  ];

  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
  };

  xdg.configFile = {
    qt5ct = {
      target = "qt5ct/qt5ct.conf";
      force = true;
      text = qtCtAppearanceConfig;
    };

    qt6ct = {
      target = "qt6ct/qt6ct.conf";
      force = true;
      text = qtCtAppearanceConfig;
    };

    kvantum = {
      target = "Kvantum/kvantum.kvconfig";
      text = generators.toINI { } {
        General = {
          theme = kvantumThemeName;
        };
      };
    };
  };
}
