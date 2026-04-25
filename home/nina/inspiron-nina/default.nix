{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../../modules/home-manager/common
    ../../../desktop/hyprland/shell-backend.nix
    ../../../desktop/hyprland/user.nix
    ../../../desktop/hyprland/rice/caelestia-config.nix
    ../../shared/dev-workstation.nix
  ];

  kryonix.shell.backend = "caelestia";

  kryonix.shell.caelestia.settings = {
    appearance.transparency = {
      enabled = false;
      base = 1.0;
      layers = 1.0;
    };

    border = {
      rounding = 16;
      smoothing = 26;
      thickness = 6;
    };

    dashboard = {
      enabled = true;
      showMedia = false;
      showPerformance = false;
      showWeather = false;
    };

    background.visualiser = {
      enabled = false;
      blur = false;
    };

    services.visualiserBars = 0;

    general.apps = {
      terminal = [ "kryonix-terminal" ];
      explorer = [ "dolphin" ];
      audio = [ "pavucontrol" ];
    };

    launcher = {
      showOnHover = false;
      maxShown = 8;
      maxWallpapers = 6;
      favouriteApps = [
        "google-chrome"
        "code"
        "org.kde.dolphin"
        "psim"
      ];
    };

    paths.wallpaperDir = "~/.local/share/wallpapers";
    sidebar.enabled = true;
    utilities.enabled = true;
  };

  kryonix.vscode.extraExtensions = [
    "vsciot-vscode.vscode-arduino"
    "platformio.platformio-ide"
  ];

  kryonix.vscode.extraSettings = {
    "arduino.useArduinoCli" = true;
  };

  home.packages = with pkgs; [
    google-chrome
  ];

  home.sessionVariables = {
    ARDUINO_SKETCHBOOK_DIR = "${config.home.homeDirectory}/Arduino";
    PSIM_WINEPREFIX = "${config.home.homeDirectory}/.local/share/wineprefixes/psim";
  };

  xdg.desktopEntries.psim = {
    name = "PSIM";
    genericName = "Circuit Simulator";
    comment = "PSIM executado via Wine";
    exec = "psim";
    terminal = false;
    categories = [
      "Development"
      "Education"
      "Engineering"
    ];
    icon = "wine";
    startupNotify = true;
  };

  home.activation.ensureElectronicsWorkspace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p \
      "$HOME/Arduino" \
      "$HOME/.local/share/wineprefixes" \
      "$HOME/.local/share/psim-installers"
  '';
}
