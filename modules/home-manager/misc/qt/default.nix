{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  iconThemeName = lib.attrByPath [ "gtk" "iconTheme" "name" ] null config;

  # Detecta se tema Bart está habilitado
  bartEnabled = lib.attrByPath [ "rag" "theme" "bart" "enable" ] false config;
  kvantumThemeName =
    if bartEnabled then
      lib.attrByPath [ "rag" "theme" "bart" "kvantumTheme" ] "Bart" config
    else
      "WhiteSurDark";

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

    # Kvantum: configuração é gerenciada pelo módulo de tema ativo (ex.: Bart)
    # Este arquivo só é criado se nenhum tema estiver ativo
    kvantum = lib.mkIf (!bartEnabled) {
      target = "Kvantum/kvantum.kvconfig";
      text = generators.toINI { } {
        General = {
          theme = kvantumThemeName;
        };
      };
    };
  };
}
