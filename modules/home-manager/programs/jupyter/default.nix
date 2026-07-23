# Home Manager: Jupyter (Lab) + kernels (Python/Rust/C++/Node)
#
# Objetivo
# - Ter um ambiente Jupyter pronto no usuário, sem depender de instalações imperativas.
# - Fornecer "pip mutável" de forma Nix-friendly via venv (fora do /nix/store).
#
# Notas
# - Evitamos instalar libs Python via pip global; use o venv gerido por este módulo.
# - Os kernels (C++/Node/Rust) são instalados de forma declarativa no PATH, mas
#   o registro (kernelspec) acontece via activation para ficar em ~/.local/share.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.jupyter;

  # Python environment with JupyterLab + ipykernel.
  # Note: this environment already provides `bin/python`, but it may also ship `bin/jupyter`.
  python = pkgs.python3.withPackages (ps: [
    ps.jupyterlab
    ps.notebook
    ps.ipykernel
  ]);

  pythonBin = "${python}/bin/python";

  # Single entrypoint: `jupyter` wrapper. We run Jupyter via module invocation so we don't
  # depend on a `bin/jupyter` provided by the python env and avoid PATH collisions.
  jupyterLauncher = pkgs.writeShellScriptBin "jupyter" ''
    set -euo pipefail
    exec "${pythonBin}" -m jupyter lab "$@"
  '';

  # Helper: attempt to register a kernelspec only if the command exists.
  # This avoids failing when a kernel isn't available on the channel.
  bootstrapScript = pkgs.writeShellScript "jupyter-bootstrap" ''
    set -euo pipefail

    mkdir -p "$HOME/.local/share/jupyter"

    if [ "${lib.boolToString cfg.kernels.python}" = "true" ]; then
      "${pythonBin}" -m ipykernel install --user --name python-nix --display-name "Python (nix)"
    fi

    if [ "${lib.boolToString cfg.kernels.rust}" = "true" ]; then
      # Algumas versões expõem o instalador como `evcxr_jupyter` (não `evcxr`).
      if command -v evcxr_jupyter >/dev/null 2>&1; then
        evcxr_jupyter --install
      else
        echo "[jupyter-bootstrap] evcxr_jupyter não encontrado no PATH" >&2
      fi
    fi

    if [ "${lib.boolToString cfg.kernels.cpp}" = "true" ]; then
      installed_any=0
      kernels_dir="$HOME/.local/share/jupyter/kernels"
      mkdir -p "$kernels_dir"

      prepare_kernel_dir() {
        local spec="$1"
        local target="$kernels_dir/$spec"

        if [ -e "$target" ]; then
          # Alguns kernelspecs copiados do nix store preservam permissões readonly.
          # Tornamos o diretório gravável antes de substituir para evitar falhas
          # intermitentes no `home-manager switch`.
          chmod -R u+w "$target" 2>/dev/null || true
          rm -rf "$target"
        fi
      }

      # Alguns nixpkgs expõem helpers `xcpp17-jupyter-kernel install --user`.
      for k in xcpp11-jupyter-kernel xcpp14-jupyter-kernel xcpp17-jupyter-kernel; do
        if [ -x "${pkgs.xeus-cling}/bin/$k" ]; then
          spec="''${k%-jupyter-kernel}"
          prepare_kernel_dir "$spec"
          "${pkgs.xeus-cling}/bin/$k" install --user
          installed_any=1
        fi
      done

      # Outros nixpkgs já trazem kernelspecs em `${pkgs.xeus-cling}/share/jupyter/kernels/*`.
      if [ "$installed_any" = "0" ]; then
        for spec in xcpp11 xcpp14 xcpp17; do
          if [ -d "${pkgs.xeus-cling}/share/jupyter/kernels/$spec" ]; then
            prepare_kernel_dir "$spec"
            "${pythonBin}" -m jupyter kernelspec install --user --name "$spec" "${pkgs.xeus-cling}/share/jupyter/kernels/$spec"
          fi
        done
      fi
    fi

    if [ "${lib.boolToString cfg.kernels.bash}" = "true" ]; then
      if command -v bash_kernel >/dev/null 2>&1; then
        bash_kernel install --user
      fi
    fi

    if [ "${lib.boolToString cfg.kernels.c}" = "true" ]; then
      if command -v install_c_kernel >/dev/null 2>&1; then
        install_c_kernel --user
      else
        echo "[jupyter-bootstrap] install_c_kernel não encontrado no PATH" >&2
      fi
    fi

    if [ "${lib.boolToString cfg.kernels.dotnet}" = "true" ]; then
      if command -v dotnet-interactive >/dev/null 2>&1; then
        dotnet-interactive jupyter install --user
      fi
    fi
  '';

  jupyterBootstrapCmd = pkgs.writeShellScriptBin "jupyter-bootstrap" ''
    set -euo pipefail
    exec ${bootstrapScript}
  '';

  jupyterDoctor = pkgs.writeShellScriptBin "jupyter-doctor" ''
    set -euo pipefail
    echo "[jupyter-doctor] python: ${pythonBin}"
    "${pythonBin}" -c "import jupyterlab, ipykernel; print('jupyterlab:', jupyterlab.__version__); print('ipykernel:', ipykernel.__version__)"

    echo "[jupyter-doctor] kernelspec list:"
    "${pythonBin}" -m jupyter kernelspec list || true
  '';

  # nixpkgs renamed python package `bash_kernel` -> `bash-kernel`
  bashKernelPkg =
    if pkgs.python3Packages ? "bash-kernel" then
      pkgs.python3Packages."bash-kernel"
    else
      pkgs.python3Packages.bash_kernel;

  dotnetInteractivePkg =
    if pkgs ? dotnet-interactive then
      pkgs.dotnet-interactive
    else if pkgs ? dotnetPackages && pkgs.dotnetPackages ? "dotnet-interactive" then
      pkgs.dotnetPackages."dotnet-interactive"
    else
      null;

in
{
  options.programs.jupyter = {
    enable = lib.mkEnableOption "JupyterLab via Nix (Python + ipykernel) e kernels extras";

    kernels = {
      python = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Habilita/register kernel Python (ipykernel)";
      };

      c = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Habilita kernel C (jupyter-c-kernel).";
      };

      rust = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Habilita kernel Rust (evcxr_jupyter)";
      };

      cpp = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Habilita kernel C++ (xeus-cling). Desativado por padrão pois o xeus-cling frequentemente quebra build em alguns canais (falhas em testes/kernels durante o build).";
      };

      bash = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Habilita kernel Bash (bash_kernel)";
      };

      dotnet = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Habilita kernel .NET (dotnet-interactive)";
      };

      node = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Habilita kernel Node.js (ijavascript)";
      };
    };

    autoBootstrap = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Se true, registra kernels automaticamente durante `home-manager switch` (com stamp para evitar rodar sempre).";
    };

    bootstrapIntervalDays = lib.mkOption {
      type = lib.types.int;
      default = 7;
      description = "Intervalo (em dias) para re-rodar o bootstrap automaticamente.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Do NOT add the full python env to home.packages, because it includes `bin/jupyter`
    # which conflicts with nixpkgs `jupyter` package in some profiles. We only expose the
    # wrapper and kernel helpers.
    home.packages = [
      jupyterLauncher
      jupyterDoctor
      jupyterBootstrapCmd
    ]
    ++ lib.optionals cfg.kernels.c [ pkgs.python3Packages."jupyter-c-kernel" ]
    ++ lib.optionals cfg.kernels.rust [ pkgs.evcxr ]
    ++ lib.optionals (cfg.kernels.cpp && pkgs ? xeus-cling) [ pkgs.xeus-cling ]
    ++ lib.optionals cfg.kernels.bash [ bashKernelPkg ]
    ++ lib.optionals (cfg.kernels.dotnet && dotnetInteractivePkg != null) [ dotnetInteractivePkg ];

    assertions = [
      {
        assertion = !(cfg.kernels.dotnet && dotnetInteractivePkg == null);
        message = "programs.jupyter.kernels.dotnet=true, mas o pacote dotnet-interactive não existe neste nixpkgs. Desative dotnet ou ajuste o canal.";
      }
    ];

    # Faz o registro de kernels automaticamente (reprodutível ao migrar pra outra máquina).
    # Rodamos no máximo 1x a cada N dias (stamp), porque alguns kernels podem ser lentos.
    home.activation.jupyter-bootstrap = lib.mkIf cfg.autoBootstrap (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        STAMP="$HOME/.local/state/jupyter-bootstrap.stamp"
        mkdir -p "$(dirname "$STAMP")"

        should_run=0
        if [ ! -f "$STAMP" ]; then
          should_run=1
        else
          # GNU find (Linux). Se não suportar (ambiente estranho), roda sempre.
          if find "$STAMP" -mtime +${toString cfg.bootstrapIntervalDays} -print -quit >/dev/null 2>&1; then
            if [ -n "$(find "$STAMP" -mtime +${toString cfg.bootstrapIntervalDays} -print -quit 2>/dev/null)" ]; then
              should_run=1
            fi
          else
            should_run=1
          fi
        fi

        if [ "$should_run" = "1" ]; then
          echo "[home-manager] jupyter: registrando kernels (bootstrap)"
          ${jupyterBootstrapCmd}/bin/jupyter-bootstrap || true
          touch "$STAMP"
        fi
      ''
    );

    # No automatic activation hook.
  };
}
