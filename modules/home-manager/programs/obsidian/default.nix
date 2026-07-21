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
      unset ELECTRON_RUN_AS_NODE ELECTRON_NO_ATTACH_CONSOLE

      # GPUs híbridas/legadas + Wayland + Electron podem travar no processo GPU
      # do Chromium. Mantém Wayland ativo, mas evita o caminho GPU instável.
      exec ${pkgs.obsidian}/bin/obsidian --disable-gpu --disable-gpu-compositing "$@"
    '';
  };
  ragObsidianCompat = pkgs.writeShellApplication {
    name = "rag-obsidian";
    runtimeInputs = [ kryonixObsidian ];
    text = ''
      printf '%s\n' "rag-obsidian is deprecated, use kryonix-obsidian" >&2
      exec kryonix-obsidian "$@"
    '';
  };
in
{
  config = lib.mkIf (!pkgs.stdenv.isDarwin) {
    home.packages = [
      pkgs.obsidian
      kryonixObsidian
      ragObsidianCompat
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
