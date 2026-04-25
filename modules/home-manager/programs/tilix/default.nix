# =============================================================================
# Home Manager: Tilix
# Autor: Gabriel Rocha (rag) + Codex
# Data: 2026-03-20
#
# O que é:
# - Configuração declarativa do terminal Tilix para hosts Linux.
# - Publica um launcher estável (`kryonix-terminal`) para atalhos e scripts internos.
#
# Por quê:
# - Centraliza a escolha do terminal sem depender de wrappers específicos do Warp.
# - Mantém shell, fonte e UX consistentes com o resto do ambiente.
#
# Como:
# - Instala `pkgs.tilix`.
# - Configura o perfil via `dconf.settings`.
# - Sobrescreve o desktop entry do Tilix para abrir pelo launcher do repo.
#
# Riscos:
# - As preferências ficam no `dconf`; um ambiente sem `programs.dconf.enable = true`
#   no NixOS não vai aplicar as chaves corretamente.
# =============================================================================
{
  lib,
  pkgs,
  ...
}:
let
  tilixProfileId = "9c6ef0ae-fd91-4a52-a92f-5dfc5181e4c1";
  tilixProfileName = "Kryonix";

  kryonixTerminal = pkgs.writeShellApplication {
    name = "kryonix-terminal";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.tilix
    ];
    text = ''
      set -euo pipefail

      profile_name="${tilixProfileName}"
      geometry="170x45"
      cwd=""
      declare -a user_cmd=()

      if [[ "${"$"}{1-}" == "start" ]]; then
        shift
        while (($#)); do
          case "$1" in
            --cwd)
              [[ $# -ge 2 ]] || {
                echo "kryonix-terminal: faltou informar um diretório após --cwd" >&2
                exit 2
              }
              cwd="$2"
              shift 2
              ;;
            --)
              shift
              user_cmd=("$@")
              break
              ;;
            *)
              echo "Uso: kryonix-terminal [start [--cwd DIR] [-- comando...]]" >&2
              exit 2
              ;;
          esac
        done
      elif (($#)); then
        user_cmd=("$@")
      fi

      tilix_args=(
        --profile "$profile_name"
        --geometry "$geometry"
      )

      if [[ -n "$cwd" ]]; then
        tilix_args+=(--working-directory "$cwd")
      fi

      if ((${"$"}{#user_cmd[@]})); then
        printf -v command_string "%q " "${"$"}{user_cmd[@]}"
        command_string="${"$"}{command_string% }"
        quoted_script="$(printf "%q" "exec ${"$"}{command_string}")"
        tilix_args+=(--command "${pkgs.zsh}/bin/zsh -l -c ${"$"}{quoted_script}")
      fi

      exec tilix "${"$"}{tilix_args[@]}"
    '';
  };
in
{
  config = lib.mkIf pkgs.stdenv.isLinux {
    home.packages = [
      pkgs.tilix
      kryonixTerminal
    ];

    home.sessionVariables.TERMINAL = "kryonix-terminal";

    dconf.settings = {
      "com/gexperts/Tilix" = {
        copy-on-select = true;
        new-instance-mode = "new-window";
        prompt-on-close = false;
        prompt-on-close-process = false;
        terminal-title-show-when-single = false;
        terminal-title-style = "none";
        theme-variant = "dark";
        unsafe-paste-alert = true;
        window-style = "disable-csd-hide-toolbar";
      };

      "com/gexperts/Tilix/profiles" = {
        default = tilixProfileId;
        list = [ tilixProfileId ];
      };

      "com/gexperts/Tilix/profiles/${tilixProfileId}" = {
        background-transparency-percent = 0;
        custom-command = "${pkgs.zsh}/bin/zsh -l -c 'exec ${pkgs.zellij}/bin/zellij'";
        font = "Monocraft 12";
        scrollback-lines = 10000;
        show-scrollbar = false;
        terminal-bell = "none";
        use-custom-command = true;
        use-system-font = false;
        use-theme-colors = true;
        visible-name = tilixProfileName;
      };
    };

    xdg.desktopEntries."com.gexperts.Tilix" = {
      name = "Tilix";
      genericName = "Terminal";
      comment = "Tilix configurado pelo Home Manager";
      exec = "kryonix-terminal";
      icon = "com.gexperts.Tilix";
      terminal = false;
      startupNotify = true;
      categories = [
        "System"
        "TerminalEmulator"
      ];
      settings = {
        DBusActivatable = "false";
        Keywords = "shell;prompt;command;commandline;cmd;";
        StartupWMClass = "com.gexperts.Tilix";
      };
      actions = {
        new-window = {
          name = "New Window";
          exec = "kryonix-terminal";
        };
        preferences = {
          name = "Preferences";
          exec = "tilix --preferences";
        };
      };
    };
  };
}
