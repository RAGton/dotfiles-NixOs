{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kryonix.vscode;

  edition =
    if cfg.edition != null then
      cfg.edition
    else if cfg.flavor == "vscodium" then
      "codium"
    else
      "stable";

  delivery =
    if cfg.delivery != null then
      cfg.delivery
    else if edition == "insiders" then
      "managed-download"
    else
      "nixpkgs";

  configRootName =
    if edition == "codium" then
      "VSCodium"
    else if edition == "insiders" then
      "Code - Insiders"
    else
      "Code";

  userDataDir = "${config.home.homeDirectory}/.config/${configRootName}";
  legacyInsidersRoot = "${config.home.homeDirectory}/.local/share/ragos/vscode-insiders";
  insidersRoot = "${config.home.homeDirectory}/.local/share/kryonix/vscode-insiders";
  extensionsDir = "${insidersRoot}/extensions";
  insidersCurrent = "${insidersRoot}/current";
  insidersUpdateUrl = "https://update.code.visualstudio.com/latest/linux-x64/insider";
  vscodeRuntimeLibraries = lib.makeLibraryPath [
    pkgs.alsa-lib
    pkgs.at-spi2-core
    pkgs.cairo
    pkgs.dbus.lib
    pkgs.expat
    pkgs.glib
    pkgs.gtk3
    pkgs.libdbusmenu
    pkgs.libgbm
    pkgs.libglvnd
    pkgs.libsecret
    pkgs.libxcb
    pkgs.libx11
    pkgs.libxcomposite
    pkgs.libxdamage
    pkgs.libxext
    pkgs.libxfixes
    pkgs.libxkbcommon
    pkgs.libxrandr
    pkgs.nspr
    pkgs.nss
    pkgs.pango
    pkgs.stdenv.cc.cc.lib
    pkgs.systemd
    pkgs.wayland
  ];
  vscodeGioModules = lib.makeSearchPath "lib/gio/modules" [
    (lib.getLib pkgs.dconf)
  ];
  vscodeXdgDataDirs = lib.makeSearchPath "share" [
    pkgs.gsettings-desktop-schemas
    pkgs.gtk3
  ];
  vscodePixbufModuleFile = "${pkgs.librsvg}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache";

  baseVscodeSettings = {
    "workbench.colorTheme" = "Dracula";
    "editor.fontFamily" = "'Monocraft', monospace";
    "editor.fontSize" = 14;
    "editor.fontLigatures" = true;
    "terminal.integrated.fontFamily" = "Monocraft";
    "editor.minimap.enabled" = false;
    "editor.wordWrap" = "on";
    "terminal.integrated.scrollback" = 5000;
    "terminal.integrated.cursorStyle" = "line";
    "git.enableSmartCommit" = true;
    "git.autofetch" = true;
    "git.autofetchPeriod" = 120;
    # Direnv integration
    "direnv.path.executable" = "${pkgs.direnv}/bin/direnv";
    "direnv.restart.automatic" = true;
    "direnv.watchForChanges" = true;
  };

  vscodeSettings = baseVscodeSettings // cfg.extraSettings;
  vscodeSettingsFile = pkgs.writeText "vscode-settings.json" (builtins.toJSON vscodeSettings);

  vscodeLocale = {
    locale = "pt-br";
  };
  vscodeLocaleFile = pkgs.writeText "vscode-locale.json" (builtins.toJSON vscodeLocale);

  vscodeArgv = {
    "ozone-platform-hint" = "auto";
    "enable-features" = "UseOzonePlatform,WaylandWindowDecorations";
  };
  vscodeArgvFile = pkgs.writeText "vscode-argv.json" (builtins.toJSON vscodeArgv);

  writeMutableJson = relativePath: sourcePath: ''
    target="${config.xdg.configHome}/${relativePath}"
    target_dir="$(${pkgs.coreutils}/bin/dirname "$target")"

    $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$target_dir"

    if [ -L "$target" ] || [ ! -e "$target" ] || ! ${pkgs.diffutils}/bin/cmp -s ${sourcePath} "$target"; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -f "$target"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -Dm644 ${sourcePath} "$target"
    fi
  '';

  baseVscodeExtensions = [
    "MS-CEINTL.vscode-language-pack-pt-BR"
    "eamodio.gitlens"
    "mhutchie.git-graph"
    "ms-toolsai.jupyter"
    "rust-lang.rust-analyzer"
    "ms-vscode.cpptools"
    "ms-python.python"
    "ms-python.vscode-pylance"
    "jnoortheen.nix-ide"
    "dracula-theme.theme-dracula"
    "EditorConfig.EditorConfig"
    "Gruntfuggly.todo-tree"
    "mechatroner.rainbow-csv"
    "mkhl.direnv"
  ];

  vscodePackage = if edition == "codium" then pkgs.vscodium else pkgs.vscode;

  editorDesktopId =
    if delivery == "managed-download" then
      "code.desktop"
    else if edition == "codium" then
      "codium.desktop"
    else
      "code.desktop";

  editorMimeTypes = [
    "text/plain"
    "application/x-zerosize"
    "application/x-desktop"
    "application/json"
    "application/x-ipynb+json"
    "application/xml"
    "application/x-shellscript"
    "text/markdown"
    "text/css"
    "text/x-ini"
    "text/x-python"
    "text/x-readme"
    "text/x-script.python"
    "text/x-yaml"
    "text/x-c"
    "text/x-c++"
    "text/x-c++hdr"
    "text/x-c++src"
    "text/x-chdr"
    "text/x-csrc"
    "text/x-java"
    "text/x-makefile"
    "text/x-moc"
    "text/x-pascal"
    "text/x-tcl"
    "text/x-tex"
  ];
  editorDesktopMimeTypes = lib.concatStringsSep ";" (editorMimeTypes ++ [ "inode/directory" ]) + ";";

  renderDesktopEntry =
    {
      name,
      comment,
      exec,
    }:
    ''
      [Desktop Entry]
      Type=Application
      Version=1.0
      Name=${name}
      GenericName=Code Editor
      Comment=${comment}
      Exec=${exec}
      Terminal=false
      Categories=Development;IDE;TextEditor;
      MimeType=${editorDesktopMimeTypes}
      Icon=${insidersCurrent}/resources/app/resources/linux/code.png
      StartupNotify=true
    '';

  vscodeExtensions = lib.unique (baseVscodeExtensions ++ cfg.extraExtensions);

  codeInsiders = pkgs.writeShellApplication {
    name = "code-insiders";
    runtimeInputs = [
      pkgs.coreutils
    ];
    text = ''
      set -euo pipefail

      current_dir="${insidersCurrent}"
      binary=""

      for candidate in \
        "$current_dir/bin/code" \
        "$current_dir/bin/code-insiders" \
        "$current_dir/code" \
        "$current_dir/code-insiders"; do
        if [ -x "$candidate" ]; then
          binary="$candidate"
          break
        fi
      done

      if [ -z "$binary" ]; then
        echo "code-insiders: VS Code Insiders ainda não foi baixado." >&2
        echo "code-insiders: rode 'systemctl --user start vscode-insiders-refresh.service' e tente novamente." >&2
        exit 1
      fi

      export GIO_EXTRA_MODULES="${vscodeGioModules}''${GIO_EXTRA_MODULES:+:$GIO_EXTRA_MODULES}"
      export GDK_PIXBUF_MODULE_FILE="${vscodePixbufModuleFile}"
      export XDG_DATA_DIRS="${vscodeXdgDataDirs}''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
      export LD_LIBRARY_PATH="${vscodeRuntimeLibraries}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

      exec "$binary" \
        --user-data-dir "${userDataDir}" \
        --extensions-dir "${extensionsDir}" \
        "$@"
    '';
  };

  codeCompat = pkgs.writeShellApplication {
    name = "code";
    runtimeInputs = [
      codeInsiders
    ];
    text = ''
      set -euo pipefail

      exec code-insiders "$@"
    '';
  };

  vscodeBootstrap = pkgs.writeShellApplication {
    name = "vscode-bootstrap";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
    ];
    text = ''
      set -euo pipefail

      extension_cli="${
        if delivery == "managed-download" then
          "${codeInsiders}/bin/code-insiders"
        else
          lib.getExe vscodePackage
      }"

      if ! "$extension_cli" --version >/dev/null 2>&1; then
        echo "vscode-bootstrap: editor indisponível; pulando." >&2
        exit 0
      fi

      installed="$("$extension_cli" --list-extensions 2>/dev/null || true)"

      for ext in \
        ${lib.concatStringsSep " \\\n        " (map lib.escapeShellArg vscodeExtensions)}; do
        if ! printf '%s\n' "$installed" | grep -Fxiq "$ext"; then
          echo "vscode-bootstrap: instalando extensão $ext"
          if ! "$extension_cli" --install-extension "$ext" --force >/dev/null 2>&1; then
            echo "vscode-bootstrap: falha ao instalar $ext (galeria/extensão incompatível com a edição atual?)" >&2
          fi
        fi
      done

      schema_target=""

      for root in \
        "${extensionsDir}" \
        "$HOME/.vscode/extensions" \
        "$HOME/.vscode-oss/extensions"; do
        if [ -d "$root" ]; then
          candidate="$(find "$root" -path '*/continue.continue*/config-yaml-schema.json' -print -quit 2>/dev/null || true)"
          if [ -n "$candidate" ]; then
            schema_target="$candidate"
            break
          fi
        fi
      done

      if [ -n "$schema_target" ]; then
        compat_dir="$HOME/.vscode/extensions/continue.continue-1.2.10-linux-x64"
        mkdir -p "$compat_dir"
        ln -sfn "$schema_target" "$compat_dir/config-yaml-schema.json"
      fi
    '';
  };

  codeInsidersRefresh = pkgs.writeShellApplication {
    name = "vscode-insiders-refresh";
    runtimeInputs = [
      vscodeBootstrap
      pkgs.coreutils
      pkgs.curl
      pkgs.findutils
      pkgs.gnugrep
      pkgs.gzip
      pkgs.gnutar
    ];
    text = ''
      set -euo pipefail

      base_dir="${insidersRoot}"
      versions_dir="$base_dir/versions"
      metadata_file="$base_dir/latest-url"
      tmp_dir="$(mktemp -d)"

      cleanup() {
        rm -rf "$tmp_dir"
      }

      trap cleanup EXIT

      mkdir -p "$versions_dir" "${extensionsDir}"

      find_binary() {
        local root="$1"

        for candidate in \
          "$root/bin/code" \
          "$root/bin/code-insiders" \
          "$root/code" \
          "$root/code-insiders"; do
          if [ -x "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
          fi
        done

        return 1
      }

      resolved_url="$(curl -fsSIL -o /dev/null -w '%{url_effective}' -L "${insidersUpdateUrl}")"

      if [ -z "$resolved_url" ]; then
        echo "vscode-insiders-refresh: não foi possível resolver a URL da build." >&2
        exit 1
      fi

      if [ -f "$metadata_file" ] && [ "$(cat "$metadata_file")" = "$resolved_url" ] && [ -L "$base_dir/current" ]; then
        echo "vscode-insiders-refresh: já está atualizado."
        exit 0
      fi

      archive="$tmp_dir/vscode-insiders.tar.gz"
      extract_dir="$tmp_dir/extracted"
      mkdir -p "$extract_dir"

      curl -fsSL "$resolved_url" -o "$archive"
      tar -xzf "$archive" -C "$extract_dir"

      app_dir="$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)"

      if [ -z "$app_dir" ] || ! find_binary "$app_dir" >/dev/null; then
        echo "vscode-insiders-refresh: estrutura inesperada da build baixada." >&2
        exit 1
      fi

      version_key="$(printf '%s' "$resolved_url" | sha256sum | cut -d' ' -f1)"
      target_dir="$versions_dir/$version_key"

      rm -rf "$target_dir"
      mv "$app_dir" "$target_dir"
      ln -sfn "$target_dir" "$base_dir/current"
      printf '%s\n' "$resolved_url" > "$metadata_file"

      # Cleanup older versions (keep only the current one) to prevent disk bloat
      find "$versions_dir" -mindepth 1 -maxdepth 1 -type d ! -name "$version_key" -exec rm -rf {} +

      vscode-bootstrap || true
    '';
  };
in
{
  options.kryonix.vscode = {
    enable = lib.mkEnableOption "Configura uma única origem de verdade para o VSCode";

    edition = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "stable"
          "codium"
          "insiders"
        ]
      );
      default = null;
      description = "Edição desejada do editor.";
    };

    delivery = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "nixpkgs"
          "managed-download"
        ]
      );
      default = null;
      description = "Como entregar a edição escolhida.";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Configurações adicionais mescladas ao settings.json do VS Code.";
    };

    extraExtensions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Lista de extensões extras instaladas além do conjunto base.";
    };

    channel = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "unstable"
          "stable"
        ]
      );
      default = null;
      visible = false;
      description = "Opção legada. Use kryonix.vscode.edition.";
    };

    flavor = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "vscode"
          "vscodium"
        ]
      );
      default = null;
      visible = false;
      description = "Opção legada. Use kryonix.vscode.edition.";
    };

    installMethod = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "flatpak"
          "nixpkgs"
        ]
      );
      default = null;
      visible = false;
      description = "Opção legada. O caminho flatpak foi removido.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = cfg.installMethod != "flatpak";
            message = "kryonix.vscode.installMethod=flatpak foi removido. Use kryonix.vscode.edition/delivery.";
          }
          {
            assertion = !(edition == "insiders" && delivery != "managed-download");
            message = "kryonix.vscode.edition=\"insiders\" exige kryonix.vscode.delivery=\"managed-download\".";
          }
          {
            assertion = !(edition != "insiders" && delivery == "managed-download");
            message = "kryonix.vscode.delivery=\"managed-download\" só é suportado com edition=\"insiders\".";
          }
        ];

        warnings =
          lib.optionals (cfg.channel != null) [
            "kryonix.vscode.channel está deprecated e agora é ignorado; use kryonix.vscode.edition/kryonix.vscode.delivery."
          ]
          ++ lib.optionals (cfg.flavor != null || cfg.installMethod != null) [
            "kryonix.vscode.flavor/installMethod estão deprecated; use kryonix.vscode.edition/kryonix.vscode.delivery."
          ];

        xdg.mimeApps.defaultApplications = lib.genAttrs editorMimeTypes (_: lib.mkDefault editorDesktopId);

        home.activation.vscodeMutableConfigFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          ${writeMutableJson "${configRootName}/User/settings.json" vscodeSettingsFile}
          ${writeMutableJson "${configRootName}/User/locale.json" vscodeLocaleFile}
          ${writeMutableJson "${configRootName}/argv.json" vscodeArgvFile}
        '';

        home.activation.vscodeKryonixStateCompat = lib.hm.dag.entryAfter [ "vscodeMutableConfigFiles" ] ''
          if [ ! -e ${lib.escapeShellArg insidersRoot} ] && [ -e ${lib.escapeShellArg legacyInsidersRoot} ]; then
            mkdir -p "$(dirname ${lib.escapeShellArg insidersRoot})"
            ln -s ${lib.escapeShellArg legacyInsidersRoot} ${lib.escapeShellArg insidersRoot}
          fi
        '';

        home.activation.vscodeBootstrap = lib.hm.dag.entryAfter [ "vscodeKryonixStateCompat" ] ''
          echo "[home-manager] vscode: sincronizando extensões"
          ${vscodeBootstrap}/bin/vscode-bootstrap || true
        '';
      }

      (lib.mkIf (delivery == "nixpkgs") {
        home.packages = [ vscodePackage ];
      })

      (lib.mkIf (delivery == "managed-download") {
        home.packages = [
          vscodeBootstrap
          codeCompat
          codeInsiders
          codeInsidersRefresh
        ];

        xdg.dataFile."applications/code.desktop" = {
          force = true;
          text = renderDesktopEntry {
            name = "Visual Studio Code";
            comment = "Alias compatível para o VS Code Insiders";
            exec = "code %F";
          };
        };

        xdg.dataFile."applications/code-insiders.desktop" = {
          force = true;
          text = renderDesktopEntry {
            name = "Visual Studio Code Insiders";
            comment = "VS Code Insiders com estado isolado";
            exec = "code-insiders %F";
          };
        };

        systemd.user.services."vscode-insiders-refresh" = {
          Unit = {
            Description = "Refresh the managed VS Code Insiders installation";
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${codeInsidersRefresh}/bin/vscode-insiders-refresh";
          };
        };

        systemd.user.timers."vscode-insiders-refresh" = {
          Unit = {
            Description = "Refresh the managed VS Code Insiders installation daily";
          };
          Timer = {
            OnStartupSec = "2m";
            OnUnitActiveSec = "1d";
            Persistent = true;
            Unit = "vscode-insiders-refresh.service";
          };
          Install = {
            WantedBy = [ "timers.target" ];
          };
        };
      })
    ]
  );
}
