{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kryonix.programs.aiWorkstation;

  claudeWrapper = pkgs.writeShellApplication {
    name = "claude";
    runtimeInputs = [ pkgs.nodejs_22 ];
    text = ''
      set -euo pipefail
      exec npx --yes @anthropic-ai/claude-code "$@"
    '';
  };
  claudePackage = pkgs.claude-code or claudeWrapper;

  traeLauncher = pkgs.writeShellApplication {
    name = "trae-launcher";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
    ];
    text = ''
      set -euo pipefail

      for candidate in \
        "''${TRAE_BIN:-}" \
        "$(command -v trae 2>/dev/null || true)" \
        "$HOME/.local/bin/trae" \
        "/opt/trae/trae"; do
        if [ -n "$candidate" ] && [ -x "$candidate" ]; then
          exec "$candidate" "$@"
        fi
      done

      echo "trae-launcher: Trae nao encontrado." >&2
      echo "trae-launcher: instale o .deb/.rpm oficial e exponha o binario em PATH, ~/.local/bin/trae, /opt/trae/trae ou TRAE_BIN." >&2
      exit 1
    '';
  };
in
{
  imports = [ ../obsidian ];

  options.kryonix.programs.aiWorkstation = {
    enable = lib.mkEnableOption "ferramentas de estudo, IDE e IA no perfil do usuario";

    enableTraeLauncher = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Instala o wrapper e a entrada desktop do Trae sem empacotar o binario.";
    };

    enableCodex = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Instala o Codex CLI (pode requerer compilacao local lenta).";
    };
  };

  config = lib.mkIf (!pkgs.stdenv.isDarwin && cfg.enable) {
    home.packages = [
      pkgs.nodejs_22
      claudePackage
    ]
    ++ lib.optionals cfg.enableTraeLauncher [ traeLauncher ]
    ++ lib.optionals cfg.enableCodex [ pkgs.codex-cli ];

    home.shellAliases = {
      ai-claude = "claude";
      ai-launch = "caelestia shell drawers toggle launcher";
      ai-trae = "trae-launcher";
      kb = "kryonix-obsidian";
    }
    // lib.optionalAttrs cfg.enableCodex {
      ai-codex = "codex";
    };

    xdg.desktopEntries = lib.mkIf cfg.enableTraeLauncher {
      trae = {
        name = "Trae";
        genericName = "AI IDE";
        comment = "Launcher manual do Trae para instalacoes externas ao Nix";
        exec = "trae-launcher %U";
        terminal = false;
        categories = [
          "Development"
          "IDE"
        ];
      };
    };
  };
}
