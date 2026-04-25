{ pkgs, lib, ... }:
{
  imports = [
    ../../../modules/home-manager/common
    ../../../desktop/hyprland/shell-backend.nix
    ../../../desktop/hyprland/user.nix
    ../../../desktop/hyprland/rice/caelestia-config.nix
    ../shared/vscode.nix
  ];

  kryonix.shell.backend = "caelestia";
  kryonix.programs.aiWorkstation.enable = true;

  kryonix.flatpak.enable = false;

  programs.home-manager.enable = true;

  programs.jupyter = {
    enable = true;
    kernels = {
      python = true;
      c = true;
      rust = true;
      cpp = true;
      bash = true;
    };
  };

  kryonix.vscode = {
    enable = true;
    edition = "codium";
    delivery = "nixpkgs";
  };

  # Ajustes específicos do host NVIDIA.
  # Mantém o base config compartilhado e só complementa o necessário.
  wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
    general {
      gaps_in = 6
      gaps_out = 14
      border_size = 3
      allow_tearing = true
    }

    decoration {
      rounding = 8
      active_opacity = 1.0
      inactive_opacity = 1.0

      blur {
        enabled = false
      }

      shadow {
        enabled = false
      }
    }

    animations {
      enabled = true
      animation = windows, 1, 3, default
      animation = fade, 1, 3, default
      animation = border, 0
      animation = workspaces, 0
      animation = layers, 0
    }

  '';

  kryonix.shell.caelestia.settings = {
    appearance.transparency = {
      enabled = false;
      base = 1.0;
      layers = 1.0;
    };

    border = {
      rounding = 22;
      smoothing = 30;
      thickness = 9;
    };

    dashboard = {
      enabled = true;
      showMedia = true;
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
      maxShown = 10;
      maxWallpapers = 9;
      favouriteApps = [
        "obsidian"
        "steam"
        "heroic"
        "lutris"
        "codium"
        "trae"
        "com.gexperts.Tilix"
        "org.kde.dolphin"
        "org.kde.filelight"
        "virt-manager"
      ];
    };

    paths.wallpaperDir = "~/.local/share/wallpapers";
    sidebar.enabled = true;
    utilities.enabled = true;
  };

  home.packages = with pkgs; [
    google-chrome
  ];

  xdg.mimeApps.defaultApplications = {
    "text/html" = lib.mkForce [ "google-chrome.desktop" ];
    "x-scheme-handler/http" = lib.mkForce [ "google-chrome.desktop" ];
    "x-scheme-handler/https" = lib.mkForce [ "google-chrome.desktop" ];
    "x-scheme-handler/ftp" = lib.mkForce [ "google-chrome.desktop" ];
    "application/xhtml+xml" = lib.mkForce [ "google-chrome.desktop" ];
    "application/x-extension-htm" = lib.mkForce [ "google-chrome.desktop" ];
    "application/x-extension-html" = lib.mkForce [ "google-chrome.desktop" ];
    "application/x-extension-shtml" = lib.mkForce [ "google-chrome.desktop" ];
    "application/x-extension-xhtml" = lib.mkForce [ "google-chrome.desktop" ];
    "application/x-extension-xht" = lib.mkForce [ "google-chrome.desktop" ];
  };

  home.stateVersion = "26.05";

  xdg.configFile."gtk-3.0/settings.ini".force = true;
  xdg.configFile."gtk-4.0/settings.ini".force = true;
}
