{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kryonix.shell.caelestia;
  blueScheme = {
    name = "rag-blue";
    flavour = "blue";
    mode = "dark";
    colours = {
      primary_paletteKeyColor = "76aef5";
      secondary_paletteKeyColor = "8fb2dd";
      tertiary_paletteKeyColor = "9bb4ff";
      neutral_paletteKeyColor = "101726";
      neutral_variant_paletteKeyColor = "263149";
      background = "101726";
      onBackground = "e6eefc";
      surface = "101726";
      surfaceDim = "101726";
      surfaceBright = "2d3444";
      surfaceContainerLowest = "0c111c";
      surfaceContainerLow = "151b27";
      surfaceContainer = "1a2130";
      surfaceContainerHigh = "222838";
      surfaceContainerHighest = "2c3243";
      onSurface = "e6eefc";
      surfaceVariant = "263149";
      onSurfaceVariant = "c4d1e8";
      inverseSurface = "e6eefc";
      inverseOnSurface = "161c28";
      outline = "7d8ba5";
      outlineVariant = "263149";
      shadow = "000000";
      scrim = "000000";
      surfaceTint = "76aef5";
      primary = "76aef5";
      onPrimary = "0b1625";
      primaryContainer = "1d3960";
      onPrimaryContainer = "d9e4ff";
      inversePrimary = "9ac5ff";
      secondary = "8fb2dd";
      onSecondary = "0e1b2b";
      secondaryContainer = "20344d";
      onSecondaryContainer = "d4e3fa";
      tertiary = "9bb4ff";
      onTertiary = "111c2f";
      tertiaryContainer = "243a5e";
      onTertiaryContainer = "dde8ff";
      error = "ffb4ab";
      onError = "690005";
      errorContainer = "93000a";
      onErrorContainer = "ffdad6";
      success = "a7d4bf";
      onSuccess = "082117";
      successContainer = "1f4634";
      onSuccessContainer = "c8f5df";
      primaryFixed = "d9e4ff";
      primaryFixedDim = "9ac5ff";
      onPrimaryFixed = "0b1625";
      onPrimaryFixedVariant = "1d3960";
      secondaryFixed = "d4e3fa";
      secondaryFixedDim = "8fb2dd";
      onSecondaryFixed = "0e1b2b";
      onSecondaryFixedVariant = "20344d";
      tertiaryFixed = "dde8ff";
      tertiaryFixedDim = "9bb4ff";
      onTertiaryFixed = "111c2f";
      onTertiaryFixedVariant = "243a5e";
      term0 = "101726";
      term1 = "76aef5";
      term2 = "8fc0ff";
      term3 = "b2d3ff";
      term4 = "c7dbff";
      term5 = "a5c8ff";
      term6 = "d0e0ff";
      term7 = "edf4ff";
      term8 = "505b72";
      term9 = "5e96f0";
      term10 = "9ac5ff";
      term11 = "ffffff";
      term12 = "76aef5";
      term13 = "8fb2dd";
      term14 = "b9d0ff";
      term15 = "ffffff";
    };
  };
  shellSettingsFile =
    if cfg.settings != { } then
      pkgs.writeText "caelestia-shell.json" (builtins.toJSON cfg.settings)
    else
      null;
  shellTokensFile =
    if cfg.tokens != { } then
      pkgs.writeText "caelestia-shell-tokens.json" (builtins.toJSON cfg.tokens)
    else
      null;
  shellSchemeFile = pkgs.writeText "caelestia-scheme.json" (builtins.toJSON cfg.scheme);
  shellWallpaperPathFile = pkgs.writeText "caelestia-wallpaper-path.txt" "${builtins.toString config.wallpaper}\n";

  writeMutableFile = target: sourcePath: ''
    target_dir="$(${pkgs.coreutils}/bin/dirname "${target}")"

    $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$target_dir"

    if [ -L "${target}" ] || [ ! -e "${target}" ] || ! ${pkgs.diffutils}/bin/cmp -s ${sourcePath} "${target}"; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -f "${target}"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -Dm644 ${sourcePath} "${target}"
    fi
  '';
in
{
  options.kryonix.shell.caelestia = {
    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = ''
        Configuração user-level do `~/.config/caelestia/shell.json`.

        Este módulo publica apenas dados de configuração do shell. A ativação
        principal do Caelestia continua sendo feita no NixOS.
      '';
    };

    tokens = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Conteúdo opcional de `~/.config/caelestia/shell-tokens.json`.";
    };

    scheme = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = blueScheme;
      description = "Estado inicial de `~/.local/state/caelestia/scheme.json`.";
    };
  };

  config = lib.mkIf ((config.kryonix.shell.backend or null) == "caelestia") {
    kryonix.shell.caelestia.settings.launcher.useFuzzy.apps = lib.mkDefault false;

    # Caelestia Hybrid Mode: Symlinks point to the live repository
    # This allows the UI to modify files and the watcher to commit them.
    xdg.configFile."caelestia/shell.json".source =
      config.lib.file.mkOutOfStoreSymlink "/etc/kryonixos/user/caelestia/shell.json";

    xdg.configFile."caelestia/shell-tokens.json".source =
      config.lib.file.mkOutOfStoreSymlink "/etc/kryonixos/user/caelestia/shell-tokens.json";

    home.file.".local/state/caelestia/scheme.json".source =
      config.lib.file.mkOutOfStoreSymlink "/etc/kryonixos/user/caelestia/scheme.json";

    # Compatibility symlink for QuickShell if needed
    home.file.".config/quickshell/shell.json".source =
      config.lib.file.mkOutOfStoreSymlink "/etc/kryonixos/user/caelestia/shell.json";

    home.activation.caelestiaHybridInit = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
      caelestia_repo_dir="/etc/kryonixos/user/caelestia"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$caelestia_repo_dir"

      # Initialize files if they don't exist in the repo
      if [ ! -e "$caelestia_repo_dir/shell.json" ] && [ "${
        if shellSettingsFile != null then "true" else "false"
      }" = "true" ]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/cp ${
          if shellSettingsFile != null then shellSettingsFile else "/dev/null"
        } "$caelestia_repo_dir/shell.json"
      fi
      if [ ! -e "$caelestia_repo_dir/shell-tokens.json" ] && [ "${
        if shellTokensFile != null then "true" else "false"
      }" = "true" ]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/cp ${
          if shellTokensFile != null then shellTokensFile else "/dev/null"
        } "$caelestia_repo_dir/shell-tokens.json"
      fi
      if [ ! -e "$caelestia_repo_dir/scheme.json" ]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/cp ${shellSchemeFile} "$caelestia_repo_dir/scheme.json"
      fi
    '';

    home.activation.caelestiaMutableState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      applications_dir="${config.xdg.dataHome}/applications"
      if [ -d "$applications_dir" ]; then
        $DRY_RUN_CMD ${pkgs.desktop-file-utils}/bin/update-desktop-database "$applications_dir"
      fi

      caelestia_state_dir="${config.xdg.stateHome}/caelestia"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -f "$caelestia_state_dir"/apps.sqlite*

      ${writeMutableFile "${config.home.homeDirectory}/.local/state/caelestia/wallpaper/path.txt" shellWallpaperPathFile}
    '';
  };
}
