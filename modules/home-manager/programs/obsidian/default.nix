{
  lib,
  pkgs,
  ...
}:
let
  kryonixObsidian = pkgs.writeShellApplication {
    name = "kryonix-obsidian";
    text = ''
      export NIXOS_OZONE_WL="''${NIXOS_OZONE_WL:-1}"
      export ELECTRON_OZONE_PLATFORM_HINT="''${ELECTRON_OZONE_PLATFORM_HINT:-auto}"

      # NVIDIA + Wayland + Electron pode congelar em alguns hosts; este launcher
      # prioriza estabilidade ao abrir o Obsidian com aceleração GPU desativada.
      exec ${pkgs.obsidian}/bin/obsidian --disable-gpu "$@"
    '';
  };
in
{
  config = lib.mkIf (!pkgs.stdenv.isDarwin) {
    home.packages = [
      pkgs.obsidian
      kryonixObsidian
    ];

    # Sobrescreve a entrada `.desktop` do pacote para usar o launcher estável.
    xdg.desktopEntries.obsidian = {
      name = "Obsidian";
      genericName = "Knowledge Base";
      comment = "Obsidian com launcher estável para Wayland/NVIDIA";
      exec = "kryonix-obsidian %U";
      icon = "obsidian";
      terminal = false;
      startupNotify = true;
      categories = [ "Office" ];
      settings = {
        StartupWMClass = "obsidian";
      };
    };
  };
}
