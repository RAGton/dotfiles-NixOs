{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kryonix.home.features.desktop;
in
{
  options.kryonix.home.features.desktop = {
    kdeShortcuts.enable = lib.mkEnableOption "KDE expert shortcuts";
    kvantumTheme.enable = lib.mkEnableOption "Kvantum transparent theme";
    lockScreenTheme.enable = lib.mkEnableOption "Kryonix lock screen theme";
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.kdeShortcuts.enable {
      # Shortcuts são configurados via plasma-manager no futuro;
      # placeholder seguro por enquanto.
    })
    (lib.mkIf cfg.kvantumTheme.enable {
      home.packages = with pkgs; [ libsForQt5.qtstyleplugin-kvantum ];
    })
    (lib.mkIf cfg.lockScreenTheme.enable {
      # Tema SDDM é configurado em nível sistema (nixos/features/desktop).
    })
  ];
}
