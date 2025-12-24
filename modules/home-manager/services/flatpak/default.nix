{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [ inputs.nix-flatpak.homeManagerModules.nix-flatpak ];

  config = lib.mkIf (!pkgs.stdenv.isDarwin) {
    services.flatpak = {
      enable = true;
      packages = [ 
        "app.zen_browser.zen" 
        "com.anydesk.Anydesk"
        ];

      uninstallUnmanaged = true;
      update.auto.enable = true;
    };

    home.packages = [ pkgs.flatpak ];

    xdg.systemDirs.data = [
      "/var/lib/flatpak/exports/share"
      "${config.home.homeDirectory}/.local/share/flatpak/exports/share"
    ];
  };
}